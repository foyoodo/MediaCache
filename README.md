# MediaCache

`MediaCache` is an asynchronous media loading layer for `AVPlayer`.
It uses `AVAssetResourceLoader` + HTTP range requests to stream remote media as async chunks, while keeping caching pluggable.

## Requirements

- Swift 6.0+
- iOS 14+ / macOS 11+

## Features

- Async content metadata loading (`ContentInfo`)
- Async chunk streaming (`AsyncThrowingStream<Data, Error>`)
- HTTP `Range`-based segmented fetching
- `AVURLAsset` integration via `ResourceLoader.asset()`
- Pluggable cache interface via `Cache` protocol

## Installation

### Swift Package Manager

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

## Quick Start

### Audio

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

## Custom Cache

Implement the `Cache` protocol to add persistent caching:

```swift
struct MyCache: Cache {
    func contentInfo(of media: Media) async throws -> ContentInfo? {
        // Read from persistent storage
    }

    func save(contentInfo: ContentInfo, of media: Media) async {
        // Persist content info
    }

    func read(at offset: Int, length: Int, of media: Media) async throws -> Data? {
        // Read cached data range
    }

    func write(data: Data, at offset: Int, of media: Media) async {
        // Persist data chunk
    }
}

// Use with MediaTask
let cache = MyCache()
let task = MediaTask(session: session, media: media, cache: cache)
```

## Architecture

```
Sources/MediaCache
├── ResourceLoader/       # AVAssetResourceLoader adapter and request routing
├── Networking/           # URLSession delegate + chunked data flow
├── Cache/                # Cache protocol definitions
├── MediaTask.swift       # Per-media task lifecycle and streaming logic
└── MediaManager.swift    # Global media task manager
```

## License

MIT
