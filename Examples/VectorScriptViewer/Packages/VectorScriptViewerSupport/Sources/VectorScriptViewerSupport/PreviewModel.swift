import CoreGraphics
import Foundation
import Observation
import VectorScript
import VectorScriptRender

// Parses and renders a document's source for the preview, at the current time when it is animated.
@MainActor
@Observable
public final class PreviewModel {
    public private(set) var document: VectorScript.Document?
    public private(set) var image: CGImage?
    public private(set) var errorMessage: String?
    public var zoom: Double = 1 {
        didSet {
            render()
        }
    }
    public var displayScale: Double = 2 {
        didSet {
            render()
        }
    }
    // Seconds into the animation. Setting it shows that frame.
    public var time: Double = 0 {
        didSet {
            if time != oldValue {
                parse()
            }
        }
    }
    public private(set) var isPlaying = false
    public var animation: DocumentAnimation? {
        document?.animation
    }

    private var source: String?
    private var baseURL: URL?
    // When playback started, and the time it started from.
    private var playStart: (date: Date, time: Double)?

    public init() {}

    // `baseURL` is the document's file, which relative image paths resolve against.
    public func update(source: String, baseURL: URL?) {
        guard source != self.source || baseURL != self.baseURL else {
            return
        }
        self.source = source
        self.baseURL = baseURL
        parse()
        if let animation, time > animation.duration {
            time = 0
        }
        if animation == nil {
            pause()
        }
    }

    public func play(at date: Date = .now) {
        guard let animation else {
            return
        }
        // A finished one-shot animation starts over.
        if !animation.loops, time >= animation.duration {
            time = 0
        }
        playStart = (date, time)
        isPlaying = true
    }

    public func pause() {
        playStart = nil
        isPlaying = false
    }

    // Called on each display frame while playing.
    public func advance(to date: Date) {
        guard isPlaying, let animation, let playStart else {
            return
        }
        let elapsed = playStart.time + date.timeIntervalSince(playStart.date)
        time = animation.time(atElapsed: elapsed)
        if !animation.loops, elapsed >= animation.duration {
            pause()
        }
    }

    private func parse() {
        guard let source else {
            return
        }
        do {
            document = try VectorScript.Document(json: Data(source.utf8), baseURL: baseURL, time: time)
            errorMessage = nil
            render()
        } catch {
            // Keep the last good image on screen while the source is broken.
            errorMessage = "\(error)"
        }
    }

    private func render() {
        guard let document else {
            return
        }
        do {
            image = try Renderer(document: document).cgImage(scale: zoom * displayScale)
        } catch {
            errorMessage = "\(error)"
        }
    }
}
