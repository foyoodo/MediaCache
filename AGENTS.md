# AGENTS.md

This file only keeps high-value details needed to safely change the current codebase.

## Core model

`MediaCache` is an async streaming pipeline for `AVPlayer`:
- Content info is fetched asynchronously (`retrieveContentInfo`)
- Media data is streamed asynchronously (`AsyncThrowingStream<Data, Error>`)
- Persistent cache is an extension point (`Cache` protocol), not a built-in implementation

## Request flow (current)

- `ResourceLoader` (`Sources/MediaCache/ResourceLoader/ResourceLoader.swift`)
  - Client entry point used with `asset()`
  - Dispatches AVFoundation requests to:
    - `ContentInfoLoader` (metadata)
    - `DataLoader` (byte stream)
- `MediaManager` (`Sources/MediaCache/MediaManager.swift`)
  - Global coordinator keyed by `Media.cacheKey`
  - Reuses one `MediaTask` per cache key
  - Tracks stream lifecycle with `retainStream` / `removeStream`
- `MediaTask` (`Sources/MediaCache/MediaTask.swift`)
  - Owns per-request `SessionDataTask` objects
  - Emits `ContentInfo` or async data chunks
- `SessionDelegate` + `SessionDataTask` + `DataChunk` (`Sources/MediaCache/Networking`)
  - Converts URLSession callbacks into async outputs

## Critical behavior to preserve

- Range requests are built in `TaskContext.urlRequest` and always set `Accept-Encoding: identity`.
- URLSession callback routing is based on `sessionTask.taskDescription = media.cacheKey` (not associated-object `taskContext`).
- `CachingAVURLAsset` must call `MediaManager.default.removeStream(of:)` in `deinit`, or per-media tasks can leak.
- `MediaTask.cancel()` must finish pending continuations/streams to avoid hanging awaiters.
- `MediaTask`, `MediaManager`, loaders use locks/queues with `@unchecked Sendable`; do not assume actor isolation.

## Current limitations (do not document as finished features)

- `Cache` protocol exists, but no concrete persistent cache implementation is wired in by default.
- Tests are minimal (`Tests/MediaCacheTests/MediaCacheTests.swift` is mostly scaffold).

## Practical guidance for future edits

- Prefer `Sources/MediaCache` for implementation work; ignore `Demo/Tuist/.build` noise.
- Keep these API surfaces stable unless intentionally versioned: `Resource`, `Media`, `ResourceLoader.asset()`.
- If adding real cache persistence, wire both read and write paths in `MediaTask`.
