# MediaCache

`MediaCache` is an asynchronous media loading layer for `AVPlayer`.
It uses `AVAssetResourceLoader` + HTTP range requests to stream remote media as async chunks, while keeping caching pluggable.

## Features

- Supports `iOS 14+` and `macOS 11+`
- Async content metadata loading (`ContentInfo`)
- Async chunk streaming (`AsyncThrowingStream<Data, Error>`)
- HTTP `Range`-based segmented fetching
- `AVURLAsset` integration via `ResourceLoader.asset()`
- Pluggable cache interface via `Cache`

## Installation

Add via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/foyoodo/MediaCache.git", branch: "main")
]
```

Then link `MediaCache` in your target:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["MediaCache"]
    )
]
```

## Quick Start (Audio Example)

### 1) Use a direct audio URL

```swift
import AVFoundation
import MediaCache

let audioURL = URL(string: "https://example.com/audio/sample.mp3")!
let loader = ResourceLoader(resource: audioURL)
let asset = loader.asset()

let playerItem = AVPlayerItem(asset: asset)
let player = AVPlayer(playerItem: playerItem)
player.play()
```

## Project Structure

```text
Sources/MediaCache
├── ResourceLoader/    # AVAssetResourceLoader adapter and request routing
├── Networking/        # URLSession delegate + chunked data flow
├── Cache/             # Cache protocol definitions
├── MediaTask.swift    # Per-media task lifecycle and streaming logic
└── MediaManager.swift # Global media task manager
```

## Notes

- Caching is protocol-driven; there is no built-in persistent cache implementation yet.
- A stable `Resource.cacheKey` is important for stream/task reuse.
