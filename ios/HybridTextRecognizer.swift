//
//  HybridTextRecognizer.swift
//  VisionCameraTextRecognition
//

import MLKitTextRecognition
import MLKitVision
import NitroModules
import VisionCamera

class HybridTextRecognizer: HybridTextRecognizerSpec {
  private let recognizer: TextRecognizer

  override init() {
    self.recognizer = TextRecognizer.textRecognizer(options: TextRecognizerOptions())
    super.init()
  }

  func recognizeText(frame: any HybridFrameSpec) throws -> RecognizedText {
    let image = try frame.toMLImage()
    let ticket = try admit()
    defer { MLKitClockGuard.shared.release(ticket) }
    let text = try recognizer.results(in: image)
    return text.toRecognizedText()
  }

  func recognizeTextAsync(frame: any HybridFrameSpec) throws -> Promise<RecognizedText> {
    let promise = Promise<RecognizedText>()

    let image = try frame.toMLImage()
    let ticket = try admit()
    recognizer.process(image) { text, error in
      MLKitClockGuard.shared.release(ticket)
      if let error {
        promise.reject(withError: error)
        return
      }
      if let text {
        promise.resolve(withResult: text.toRecognizedText())
      } else {
        promise.resolve(withResult: RecognizedText(text: "", blocks: []))
      }
    }

    return promise
  }

  // Waits for a frame in flight elsewhere, as ML Kit itself would: a caller who
  // asked for this frame gets a result or an error, never a silent drop.
  private func admit() throws -> MLKitClockGuard.Ticket {
    switch MLKitClockGuard.shared.admit(waiting: true) {
    case .admitted(let ticket):
      return ticket
    case .busy, .clockBehind:
      throw RuntimeError.error(withMessage: MLKitClockGuard.clockBehindMessage)
    }
  }
}
