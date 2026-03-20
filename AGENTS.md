# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
swift build          # Build the library
swift test           # Run all tests
swift test --filter MediaCacheTests.example  # Run a single test by name
```

Requires Swift 6.0+. Targets iOS 14+ and macOS 11+.

## Core model

`MediaCache` is an async streaming pipeline for `AVPlayer` built on `AVAssetResourceLoader`:
- URL scheme is swapped (`https` → `mediacaching`) so AVFoundation triggers the custom resource loader
- Content info is fetched asynchronously (`retrieveContentInfo`)
- Media data is streamed asynchronously via HTTP range requests (`AsyncThrowingStream<Data, Error>`)
- Persistent cache is an extension point (`Cache` protocol); no concrete implementation is wired in by default

## Request flow

1. **`ResourceLoader`** (`ResourceLoader/ResourceLoader.swift`) — `AVAssetResourceLoaderDelegate`; client entry point via `ResourceLoader.asset()`; dispatches AVFoundation loading requests to `ContentInfoLoader` or `DataLoader`
2. **`MediaManager`** (`MediaManager.swift`) — singleton (`MediaManager.default`); owns the shared `URLSession` + `SessionDelegate`; keyed dictionary of `MediaTask` by `cacheKey`; reference-counts stream lifetimes via `retainStream` / `removeStream`
3. **`MediaTask`** (`MediaTask.swift`) — per-media task owner; holds `SessionDataTask` objects; implements `getContentInfo()` and `getData(using:)` with `withTaskCancellationHandler`; integrates optional `Cache` for read-before-fetch
4. **`SessionDelegate` + `SessionDataTask` + `DataChunk`** (`Networking/`) — converts `URLSessionDataDelegate` callbacks into async continuations and `AsyncThrowingStream`

## Critical behaviors to preserve

- `Accept-Encoding: identity` is set in `MediaTask.addTask(for:)`, not in `TaskContext.urlRequest`. Always keep it there to prevent content-encoding from breaking range-based byte assembly.
- URLSession callback routing uses `sessionTask.taskDescription = media.cacheKey` (set in `MediaTask`, looked up in `MediaManager`'s `getTask` closure). Do not change this routing mechanism.
- `CachingAVURLAsset` calls `MediaManager.default.removeStream(of:)` in `deinit` via an `onDeinit` closure. Removing this causes per-media task leaks.
- `MediaTask.cancel()` must drain all pending continuations and streams or awaiters will hang indefinitely.
- All concurrency in `MediaTask`, `MediaManager`, and the loaders is manual (`NSLock`, `DispatchQueue`) with `@unchecked Sendable`. Do not assume actor isolation.

## Stable public API surfaces

Changes to these require an intentional version bump: `Resource`, `Media`, `ResourceLoader.asset()`.

## Current limitations

- `Cache` protocol exists but no concrete persistent cache is wired in. To add one, wire both the read path (before network fetch) and write path (after receiving chunks) inside `MediaTask`.
- Tests (`Tests/MediaCacheTests/MediaCacheTests.swift`) are scaffold only — uses Swift Testing framework (`import Testing`) with no real assertions yet.

## Project structure

```
Sources/MediaCache
├── ResourceLoader/    # AVAssetResourceLoader adapter and request routing
├── Networking/        # URLSession delegate + chunked data flow
├── Cache/             # Cache protocol definitions
├── MediaTask.swift    # Per-media task lifecycle and streaming logic
└── MediaManager.swift # Global media task manager
```
