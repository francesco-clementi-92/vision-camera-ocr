//
//  MLKitClockGuard.swift
//  VisionCameraTextRecognition
//

import Foundation

/// Keeps ML Kit from aborting the app when the device clock goes back.
///
/// On iOS every recognizer in the process feeds one global VisionKit pipeline
/// (MLKitTextRecognitionCommon), which lives until the process exits. ML Kit
/// stamps each frame with the wall clock rather than the buffer's presentation
/// time, and the pipeline CHECKs that a stamp is not earlier than the previous
/// frame's: a failed CHECK calls `abort()`. So once the clock is set back - a
/// network time correction, or by hand - the next frame kills the app, from any
/// screen, however long after the last one.
///
/// The pipeline cannot be reset from outside, so frames go through it one at a
/// time, and a frame is refused until the wall clock has passed the latest stamp
/// ML Kit can have given. Recognition pauses for as long as the clock went back.
final class MLKitClockGuard {
  static let shared = MLKitClockGuard()

  struct Ticket {
    fileprivate let wallClock: Date
    fileprivate let uptime: TimeInterval
  }

  enum Admission {
    case admitted(Ticket)
    // Another frame is in the pipeline.
    case busy
    // `isFirst` is set on the first refusal after an admitted frame, so a caller
    // can report the pause once rather than for every frame.
    case clockBehind(isFirst: Bool)
  }

  static let clockBehindMessage =
    "The device clock went back: text recognition is paused until it passes the last frame."

  // One frame in the pipeline at a time. A semaphore rather than a lock, because
  // the frame is released on ML Kit's completion thread.
  private let slot = DispatchSemaphore(value: 1)
  private let lock = NSLock()
  private var latestStamp: Date = .distantPast
  private var hasReportedRefusal = false

  private init() {}

  /// Takes the pipeline for one frame. Every `.admitted` must be followed by
  /// `release(_:)`, or no frame is admitted again.
  func admit(waiting: Bool) -> Admission {
    if waiting {
      slot.wait()
    } else if slot.wait(timeout: .now()) == .timedOut {
      return .busy
    }
    lock.lock()
    defer { lock.unlock() }
    let now = Date()
    if now <= latestStamp {
      slot.signal()
      let isFirst = !hasReportedRefusal
      hasReportedRefusal = true
      return .clockBehind(isFirst: isFirst)
    }
    hasReportedRefusal = false
    return .admitted(Ticket(wallClock: now, uptime: ProcessInfo.processInfo.systemUptime))
  }

  func release(_ ticket: Ticket) {
    lock.lock()
    // ML Kit stamped the frame between `admit` and now. If the clock went back in
    // between, the current time is below that stamp, but the time at admission
    // plus the monotonic time elapsed since is not.
    let elapsed = ProcessInfo.processInfo.systemUptime - ticket.uptime
    latestStamp = max(latestStamp, ticket.wallClock.addingTimeInterval(elapsed), Date())
    lock.unlock()
    slot.signal()
  }
}
