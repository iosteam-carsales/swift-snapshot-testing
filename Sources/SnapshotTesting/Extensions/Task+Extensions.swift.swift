//
//  Task+Extensions.swift.swift
//  swift-snapshot-testing
//
//  Created by Kashish Verma on 27/11/25.
//

import Foundation

extension Task where Success == Never, Failure == Never {
  
  /// Suspends the current task for at least the given duration
  /// in seconds.
  ///
  /// If the task is canceled before the time ends,
  /// this function throws `CancellationError`.
  ///
  /// This function doesn't block the underlying thread.
  public static func sleep(seconds duration: Double) async throws {
    try await sleep(nanoseconds: UInt64(duration * 1000_000_000))
  }
}
