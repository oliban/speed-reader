import SwiftUI

// MARK: - Animation Durations

/// Standard animation durations for the Hyperfocus Noir design system
public enum AnimationDuration {
    /// Quick feedback animations (button presses, toggles) - 0.15s
    public static let quick: Double = 0.15
    /// Standard transitions (navigation, modal presentation) - 0.3s
    public static let standard: Double = 0.3
    /// Dramatic reveals (loading states, first appearance) - 0.5s
    public static let slow: Double = 0.5
}

// MARK: - Animation Extensions

extension Animation {
    // MARK: Core Animations

    /// Quick UI feedback animation for button presses, toggles, and immediate responses
    public static let srQuick = Animation.easeOut(duration: AnimationDuration.quick)

    /// Standard transition animation for navigation, modal presentation, and general transitions
    public static let srStandard = Animation.easeInOut(duration: AnimationDuration.standard)

    /// Slow, dramatic reveal animation for loading states and first appearances
    public static let srSlow = Animation.easeIn(duration: AnimationDuration.slow)

    /// Bouncy spring animation for playful, engaging interactions
    public static let srSpring = Animation.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)

    // MARK: Specialized Animations

    /// Gentle spring for subtle bouncy effects
    public static let srGentleSpring = Animation.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)

    /// Snappy spring for responsive, punchy interactions
    public static let srSnappySpring = Animation.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)

    // MARK: Stagger Animation Helper

    /// Creates a staggered animation delay for list items
    /// - Parameters:
    ///   - index: The index of the item in the list
    ///   - baseDelay: The base delay before animations start (default: 0)
    ///   - staggerDelay: The delay between each item (default: 0.05s)
    /// - Returns: An animation with appropriate delay for the given index
    public static func srStaggered(
        index: Int,
        baseDelay: Double = 0,
        staggerDelay: Double = 0.05
    ) -> Animation {
        Animation.srStandard.delay(baseDelay + Double(index) * staggerDelay)
    }

    /// Creates a staggered spring animation delay for list items
    /// - Parameters:
    ///   - index: The index of the item in the list
    ///   - baseDelay: The base delay before animations start (default: 0)
    ///   - staggerDelay: The delay between each item (default: 0.05s)
    /// - Returns: A spring animation with appropriate delay for the given index
    public static func srStaggeredSpring(
        index: Int,
        baseDelay: Double = 0,
        staggerDelay: Double = 0.05
    ) -> Animation {
        Animation.srSpring.delay(baseDelay + Double(index) * staggerDelay)
    }
}

// MARK: - Fade Animation Presets

/// Fade animation configuration
public struct FadeAnimation {
    public let opacity: Double
    public let animation: Animation

    /// Fade in from transparent
    public static let fadeIn = FadeAnimation(opacity: 1.0, animation: .srStandard)

    /// Quick fade in
    public static let quickFadeIn = FadeAnimation(opacity: 1.0, animation: .srQuick)

    /// Slow, dramatic fade in
    public static let slowFadeIn = FadeAnimation(opacity: 1.0, animation: .srSlow)

    /// Fade out to transparent
    public static let fadeOut = FadeAnimation(opacity: 0.0, animation: .srStandard)
}

// MARK: - Scale Animation Presets

/// Scale animation configuration
public struct ScaleAnimation {
    public let scale: CGFloat
    public let animation: Animation

    /// Scale up from small (0.8) to full size
    public static let scaleUp = ScaleAnimation(scale: 1.0, animation: .srSpring)

    /// Scale down from large (1.1) to normal
    public static let scaleDown = ScaleAnimation(scale: 1.0, animation: .srSpring)

    /// Subtle scale for hover/press states
    public static let pressScale = ScaleAnimation(scale: 0.95, animation: .srQuick)

    /// Pop scale for attention-grabbing elements
    public static let popScale = ScaleAnimation(scale: 1.05, animation: .srSnappySpring)

    /// Initial small scale for animations starting from this state
    public static let initialSmall = ScaleAnimation(scale: 0.8, animation: .srSpring)

    /// Initial large scale for animations starting from this state
    public static let initialLarge = ScaleAnimation(scale: 1.1, animation: .srSpring)
}

// MARK: - View Modifiers

/// Fade in animation modifier
struct SRFadeInModifier: ViewModifier {
    let isVisible: Bool
    let animation: Animation

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(animation, value: isVisible)
    }
}

/// Scale in animation modifier (combines scale and fade)
struct SRScaleInModifier: ViewModifier {
    let isVisible: Bool
    let animation: Animation
    let initialScale: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1.0 : 0.0)
            .scaleEffect(isVisible ? 1.0 : initialScale)
            .animation(animation, value: isVisible)
    }
}

/// Staggered appear animation modifier for list items
struct SRStaggeredAppearModifier: ViewModifier {
    let isVisible: Bool
    let index: Int
    let baseDelay: Double
    let staggerDelay: Double

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1.0 : 0.0)
            .offset(y: isVisible ? 0 : 20)
            .animation(
                .srStaggered(index: index, baseDelay: baseDelay, staggerDelay: staggerDelay),
                value: isVisible
            )
    }
}

/// Press effect modifier for interactive elements
struct SRPressEffectModifier: ViewModifier {
    let isPressed: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.srQuick, value: isPressed)
    }
}

/// Slide in animation modifier
struct SRSlideInModifier: ViewModifier {
    let isVisible: Bool
    let edge: Edge
    let animation: Animation

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1.0 : 0.0)
            .offset(slideOffset)
            .animation(animation, value: isVisible)
    }

    private var slideOffset: CGSize {
        guard !isVisible else { return .zero }
        switch edge {
        case .top: return CGSize(width: 0, height: -30)
        case .bottom: return CGSize(width: 0, height: 30)
        case .leading: return CGSize(width: -30, height: 0)
        case .trailing: return CGSize(width: 30, height: 0)
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies a fade in animation
    /// - Parameters:
    ///   - isVisible: Whether the view should be visible
    ///   - animation: The animation to use (default: srStandard)
    /// - Returns: A view with fade animation applied
    public func srFadeIn(
        isVisible: Bool = true,
        animation: Animation = .srStandard
    ) -> some View {
        modifier(SRFadeInModifier(isVisible: isVisible, animation: animation))
    }

    /// Applies a scale and fade in animation
    /// - Parameters:
    ///   - isVisible: Whether the view should be visible
    ///   - animation: The animation to use (default: srSpring)
    ///   - initialScale: The starting scale (default: 0.8)
    /// - Returns: A view with scale in animation applied
    public func srScaleIn(
        isVisible: Bool = true,
        animation: Animation = .srSpring,
        initialScale: CGFloat = 0.8
    ) -> some View {
        modifier(SRScaleInModifier(isVisible: isVisible, animation: animation, initialScale: initialScale))
    }

    /// Applies a staggered appear animation for list items
    /// - Parameters:
    ///   - isVisible: Whether the view should be visible
    ///   - index: The index of this item in the list
    ///   - baseDelay: The base delay before animations start (default: 0)
    ///   - staggerDelay: The delay between each item (default: 0.05s)
    /// - Returns: A view with staggered animation applied
    public func staggeredAppear(
        isVisible: Bool = true,
        index: Int,
        baseDelay: Double = 0,
        staggerDelay: Double = 0.05
    ) -> some View {
        modifier(SRStaggeredAppearModifier(
            isVisible: isVisible,
            index: index,
            baseDelay: baseDelay,
            staggerDelay: staggerDelay
        ))
    }

    /// Applies a press effect animation for interactive elements
    /// - Parameter isPressed: Whether the element is being pressed
    /// - Returns: A view with press effect applied
    public func srPressEffect(isPressed: Bool) -> some View {
        modifier(SRPressEffectModifier(isPressed: isPressed))
    }

    /// Applies a slide in animation from the specified edge
    /// - Parameters:
    ///   - isVisible: Whether the view should be visible
    ///   - edge: The edge to slide in from
    ///   - animation: The animation to use (default: srStandard)
    /// - Returns: A view with slide in animation applied
    public func srSlideIn(
        isVisible: Bool = true,
        from edge: Edge = .bottom,
        animation: Animation = .srStandard
    ) -> some View {
        modifier(SRSlideInModifier(isVisible: isVisible, edge: edge, animation: animation))
    }
}

// MARK: - Transition Extensions

extension AnyTransition {
    /// Fade and scale transition for appearing/disappearing elements
    public static let srScaleFade = AnyTransition.opacity.combined(with: .scale(scale: 0.9))

    /// Slide up transition
    public static let srSlideUp = AnyTransition.opacity.combined(with: .move(edge: .bottom))

    /// Slide down transition
    public static let srSlideDown = AnyTransition.opacity.combined(with: .move(edge: .top))

    /// Asymmetric transition: scale in, fade out
    public static let srScaleInFadeOut = AnyTransition.asymmetric(
        insertion: .scale(scale: 0.8).combined(with: .opacity),
        removal: .opacity
    )
}
