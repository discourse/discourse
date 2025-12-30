import Content from "./d-scroll/content";
import Root from "./d-scroll/root";
import Trigger from "./d-scroll/trigger";
import View from "./d-scroll/view";

/**
 * DScroll - Scroll component following Silk's pattern
 *
 * A primitive component for building advanced scrolling experiences.
 * Provides extra features compared to normal scroll containers.
 *
 * Usage:
 * ```hbs
 * <DScroll.Root as |scroll|>
 *   <scroll.View @axis="y" @scrollGestureTrap={{hash yEnd=true}}>
 *     <scroll.Content>
 *       ...your content...
 *     </scroll.Content>
 *   </scroll.View>
 *
 *   <DScroll.Trigger
 *     @scroll={{scroll}}
 *     @action={{hash type="scroll-to" progress=0}}
 *   >
 *     Scroll to Top
 *   </DScroll.Trigger>
 * </DScroll.Root>
 * ```
 *
 * Imperative API (via yielded scroll object):
 * - scroll.scrollTo({ progress?, distance?, animationSettings? })
 * - scroll.scrollBy({ progress?, distance?, animationSettings? })
 * - scroll.getProgress() - Returns 0-1
 * - scroll.getDistance() - Returns pixels traveled
 * - scroll.getAvailableDistance() - Returns total scrollable distance
 *
 * View Component Props:
 * - @axis - "x" or "y" (default: "y")
 * - @scrollGestureTrap - Trap scroll gestures at boundaries
 * - @scrollGestureOvershoot - Allow visual overscroll (default: true)
 * - @scrollGesture - Enable scroll gestures (default: "auto")
 * - @onScroll - Callback on scroll
 * - @onScrollStart - Callback on scroll start
 * - @onScrollEnd - Callback on scroll end
 * - @nativeFocusScrollPrevention - Prevent native focus scroll (default: true)
 * - @onFocusInside - Callback when descendant receives focus
 * - @scrollAnimationSettings - Animation settings
 * - @pageScroll - Whether this is a page scroll container
 * - @safeArea - Safe area: "none", "layout-viewport", "visual-viewport"
 * - @scrollAnchoring - Enable scroll anchoring (default: true)
 * - @scrollSnapType - CSS scroll-snap-type value
 * - @scrollPadding - CSS scroll-padding value
 * - @scrollTimelineName - CSS scroll-timeline-name value
 * - @nativeScrollbar - Show native scrollbar (default: true)
 */
const DScroll = {
  Root,
  View,
  Content,
  Trigger,
};

export default DScroll;
