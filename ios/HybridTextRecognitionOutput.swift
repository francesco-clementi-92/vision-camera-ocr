//
//  HybridTextRecognitionOutput.swift
//  VisionCameraTextRecognition
//

import AVFoundation
import MLKitTextRecognition
import MLKitVision
import NitroModules
import VisionCamera

final class HybridTextRecognitionOutput: HybridCameraOutputSpec, NativeCameraOutput {
  private let recognizer: TextRecognizer
  private let onTextRecognized: (_ result: RecognizedText) -> Void
  private let onError: (_ error: Error) -> Void
  private let outputResolution: TextRecognitionOutputResolution
  private var delegate: TextRecognitionDelegate? = nil
  private let queue: DispatchQueue

  // Guards `isBusy` and `lastErrorTimestamp` across the delegate queue and the
  // ML Kit completion thread.
  private let lock = NSLock()
  private var isBusy = false
  private var lastErrorTimestamp: Date = .distantPast

  let output: AVCaptureVideoDataOutput
  let requiresAudioInput: Bool = false
  let requiresDepthFormat: Bool = false
  let mediaType: MediaType = .video
  // Applied as metadata on the `MLImage` (see `imageOrientation`) rather than by
  // physically rotating buffers, which VisionCamera avoids because it is
  // expensive and adds latency.
  var outputOrientation: CameraOrientation = .up
  var currentResolution: Size? {
    guard let connection = output.connection(with: .video) else { return nil }
    return connection.inputStreamResolution
  }

  let streamType: StreamType = .video
  var targetResolution: ResolutionRule {
    switch outputResolution {
    case .full:
      // Prefer the highest available resolution for maximum OCR detail.
      return .min(Size(width: 3840.0, height: 2160.0))
    default:
      // Preview-sized buffers keep latency low.
      return .closestTo(Size(width: 720.0, height: 1280.0))
    }
  }

  init(options: TextRecognitionOutputOptions) {
    self.recognizer = TextRecognizer.textRecognizer(options: TextRecognizerOptions())
    self.onTextRecognized = options.onTextRecognized
    self.onError = options.onError
    self.outputResolution = options.outputResolution ?? .preview
    self.queue = DispatchQueue(label: "com.margelo.camera.textrecognition")
    self.output = AVCaptureVideoDataOutput()
    super.init()

    // set delegate
    self.delegate = TextRecognitionDelegate(onSampleBuffer: { [weak self] buffer in
      self?.recognize(buffer)
    })
    self.output.setSampleBufferDelegate(delegate, queue: queue)
    self.output.alwaysDiscardsLateVideoFrames = true
    // Force an ML Kit-compatible 8-bit BGRA pixel format. Without this the
    // output inherits the source's native format - on modern devices with
    // HDR-capable video formats (e.g. iPhone 16) that is 10-bit biplanar
    // ('x420'), which ML Kit cannot process, so OCR silently never recognizes
    // anything. The BGRA conversion is done in hardware and is cheap.
    self.output.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    if #available(iOS 17.0, *), options.outputResolution != .full {
      self.output.automaticallyConfiguresOutputBufferDimensions = false
      self.output.deliversPreviewSizedOutputBuffers = true
    }
  }

  private func recognize(_ buffer: CMSampleBuffer) {
    // Drop frames while a recognition is already in flight (back-pressure).
    lock.lock()
    if isBusy {
      lock.unlock()
      return
    }
    isBusy = true
    lock.unlock()

    guard let image = MLImage(sampleBuffer: buffer) else {
      finish()
      reportError(RuntimeError.error(withMessage: "Failed to convert CMSampleBuffer to MLImage!"))
      return
    }
    // Orientation is passed as metadata (no physical rotation). Mirroring is
    // disabled on the connection in `configure`, so the buffer is always the raw,
    // readable sensor image regardless of camera position.
    image.orientation = imageOrientation()

    recognizer.process(image) { [weak self] text, error in
      guard let self else { return }
      defer { self.finish() }
      if let error {
        self.reportError(error)
        return
      }
      if let text {
        self.onTextRecognized(text.toRecognizedText())
      }
    }
  }

  private func finish() {
    lock.lock()
    isBusy = false
    lock.unlock()
  }

  // Forward errors at most once per second so a broken frame stream can't spam
  // the JS callback.
  private func reportError(_ error: Error) {
    lock.lock()
    let now = Date()
    let shouldReport = now.timeIntervalSince(lastErrorTimestamp) >= 1.0
    if shouldReport {
      lastErrorTimestamp = now
    }
    lock.unlock()
    if shouldReport {
      onError(error)
    }
  }

  func configure(config: OutputConfiguration) {
    guard let connection = output.connection(with: .video) else {
      return
    }
    connection.preferredVideoStabilizationMode = .off
    // Force mirroring off (cheap flag, no rotation) so ML Kit receives a
    // non-mirrored, readable image. Without this the front camera auto-mirrors
    // (`automaticallyAdjustsVideoMirroring`), which flips text and breaks OCR.
    if connection.isVideoMirroringSupported {
      connection.automaticallyAdjustsVideoMirroring = false
      connection.isVideoMirrored = false
    }
  }

  // Maps the target output orientation to the `UIImage.Orientation` of the raw,
  // sensor-native buffer. Mirroring is disabled on the connection, so no mirrored
  // variants are needed.
  private func imageOrientation() -> UIImage.Orientation {
    switch outputOrientation {
    case .up:
      return .right
    case .right:
      return .down
    case .down:
      return .left
    case .left:
      return .up
    }
  }
}
