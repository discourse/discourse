import outletAnimationModifier from "./outlet-animation-modifier";

/**
 * Wrapper element with travel and stacking animation support for d-sheet.
 *
 * Use this component when you want a simple wrapper element with animation support.
 * For complex structures where you need to target a specific inner element,
 * use the outlet-animation-modifier directly instead.
 *
 * @component Outlet
 * @param {Object} sheet - The sheet controller instance managing this sheet's state
 * @param {Record<string, [string, string] | ((params: { progress: number, tween: Function }) => string) | string | null>} [travelAnimation] - Travel animation config where each property maps to a keyframe pair, animation function, static string, or null to disable
 * @param {Record<string, [string, string] | ((params: { progress: number, tween: Function }) => string) | string | null>} [stackingAnimation] - Stacking animation config (same format as travelAnimation)
 * @yields The content to be wrapped within the animated div element
 */
const Outlet = <template>
  <div
    {{outletAnimationModifier @sheet @travelAnimation @stackingAnimation}}
    ...attributes
  >
    {{yield}}
  </div>
</template>;

export default Outlet;
