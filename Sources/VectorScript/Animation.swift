// Marks a document as animated. Expressions read the time as $TIME (seconds, 0 up to duration) and the length
// as $DURATION.
public struct Animation: Sendable, Equatable, Codable {
    // Seconds.
    public var duration: Double
    public var framesPerSecond: Double
    // Plays again from the start; otherwise holds the last frame.
    public var loops: Bool

    public init(duration: Double, framesPerSecond: Double = 30, loops: Bool = true) {
        self.duration = duration
        self.framesPerSecond = framesPerSecond
        self.loops = loops
    }

    // When looping, the last frame is one step before `duration`, which is the same picture as time 0.
    public var frameCount: Int {
        max(1, Int((duration * framesPerSecond).rounded()) + (loops ? 0 : 1))
    }

    public func time(ofFrame index: Int) -> Double {
        min(duration, Double(index) / framesPerSecond)
    }

    // The time to show `elapsed` seconds after the start: wrapped when looping, held at the end when not.
    public func time(atElapsed elapsed: Double) -> Double {
        guard duration > 0 else {
            return 0
        }
        if loops {
            let wrapped = elapsed.truncatingRemainder(dividingBy: duration)
            return wrapped < 0 ? wrapped + duration : wrapped
        }
        return min(max(elapsed, 0), duration)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        try container.rejectUnknownKeys(allowed: ["duration", "fps", "loop"])
        duration = try container.decode(Double.self, "duration")
        framesPerSecond = try container.decodeIfPresent(Double.self, "fps") ?? 30
        loops = try container.decodeIfPresent(Bool.self, "loop") ?? true
        guard duration > 0 else {
            throw container.corrupted("an animation's duration must be positive")
        }
        guard framesPerSecond > 0 else {
            throw container.corrupted("fps must be positive")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: AnyKey.self)
        try container.encode(duration, "duration")
        try container.encode(framesPerSecond, "fps")
        try container.encode(loops, "loop")
    }
}
