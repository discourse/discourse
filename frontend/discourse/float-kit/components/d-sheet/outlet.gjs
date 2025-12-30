import Component from "@glimmer/component";
import outletAnimationModifier from "./outlet-animation-modifier";

/**
 * Outlet component for d-sheet - provides travel and stacking animation support.
 *
 * Use this component when you want a simple wrapper element with animation support.
 * For complex structures where you need to target a specific inner element,
 * use the outlet-animation-modifier directly instead.
 *
 * @component Outlet
 * @param {Object} sheet - The sheet controller instance
 * @param {Object} [travelAnimation] - Travel animation config
 *   Properties can be:
 *   - [start, end] array for keyframe tweening
 *   - ({ progress, tween }) => value function
 *   - string for static values
 *   - null to disable
 *   Supports: opacity, visibility, transforms (translate, scale, rotate, skew variants),
 *   and any CSS property
 * @param {Object} [stackingAnimation] - Stacking animation config (same format as travelAnimation)
 */
export default class Outlet extends Component {
  <template>
    <div
      {{outletAnimationModifier @sheet @travelAnimation @stackingAnimation}}
      ...attributes
    >
      {{yield}}
    </div>
  </template>
}
