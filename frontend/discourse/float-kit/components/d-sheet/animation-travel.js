import { SPRING_PRESETS } from "./animation";
import { travelToDetent } from "./travel";

/**
 * Default exiting animation configuration.
 *
 * @type {Object}
 */
const EXITING_ANIMATION_CONFIG = {
  easing: "spring",
  stiffness: 520,
  damping: 44,
  mass: 1,
};

/**
 * Animation travel helper for d-sheet.
 * Wraps travel logic and animation configuration resolution.
 *
 * @class AnimationTravel
 */
export default class AnimationTravel {
  /**
   * @param {Object} controller - The sheet controller instance
   */
  constructor(controller) {
    this.controller = controller;
  }

  /**
   * Get the exiting animation config.
   *
   * @returns {Object}
   */
  get exitingAnimationConfig() {
    return EXITING_ANIMATION_CONFIG;
  }

  /**
   * Resolve animation settings from string preset or object.
   *
   * @param {string|Object} settings - Animation settings
   * @returns {Object|null}
   */
  resolveAnimationSettings(settings) {
    if (!settings) {
      return null;
    }

    if (typeof settings === "string") {
      const preset = SPRING_PRESETS[settings];
      if (preset) {
        return { easing: "spring", ...preset };
      }
      return null;
    }

    if (settings.preset) {
      const preset = SPRING_PRESETS[settings.preset];
      if (preset) {
        return { easing: "spring", ...preset, ...settings };
      }
    }

    return settings;
  }

  /**
   * Get animation config for a travel to a destination detent.
   *
   * @param {number} destinationDetent - Target detent index
   * @param {string} [travelType] - Type of travel: "entering", "exiting", or "stepping"
   * @returns {Object}
   */
  getAnimationConfigForTravel(destinationDetent, travelType = null) {
    const c = this.controller;

    if (!travelType) {
      if (destinationDetent === 0) {
        travelType = "exiting";
      } else if (c.activeDetent === 0) {
        travelType = "entering";
      } else {
        travelType = "stepping";
      }
    }

    let settings;
    switch (travelType) {
      case "entering":
        settings = c.enteringAnimationSettings;
        break;
      case "exiting":
        settings = c.exitingAnimationSettings;
        break;
      case "stepping":
        settings = c.steppingAnimationSettings;
        break;
    }

    const resolved = this.resolveAnimationSettings(settings);
    if (resolved) {
      return resolved;
    }

    if (travelType === "exiting") {
      return this.exitingAnimationConfig;
    }
    return SPRING_PRESETS.smooth;
  }

  /**
   * Animate to a specific detent.
   *
   * @param {number} detentIndex - Target detent index
   * @param {Object} [animationConfig] - Optional animation config override
   */
  animateToDetent(detentIndex, animationConfig = null) {
    const c = this.controller;
    const hasProgressValues = c.dimensions?.progressValueAtDetents?.length;

    if (
      !c.scrollContainer ||
      !c.contentWrapper ||
      !c.dimensions ||
      !hasProgressValues
    ) {
      if (c.currentState === "closing" && detentIndex === 0) {
        c.handleStateTransition({ type: "ANIMATION_COMPLETE" });
      }
      return;
    }

    const resolvedConfig =
      animationConfig || this.getAnimationConfigForTravel(detentIndex);

    travelToDetent({
      destinationDetent: detentIndex,
      currentDetent: c.activeDetent,
      dimensions: c.dimensions,
      scrollContainer: c.scrollContainer,
      contentWrapper: c.contentWrapper,
      view: c.view,
      tracks: c.tracks,
      travelAnimations: c.travelAnimations,
      belowSheetsInStack: c.belowSheetsInStack,
      touchGestureActive: c.touchGestureActive,
      trackToTravelOn: c.tracks,
      animationConfig: resolvedConfig,
      setSegment: c.setSegment,
      setProgrammaticScrollOngoing: c.setProgrammaticScrollOngoing,
      swipeOutDisabledWithDetent:
        c.dimensions?.swipeOutDisabledWithDetent ?? false,
      contentPlacement: c.contentPlacement,
      hasOppositeTracks: c.tracks === "horizontal" || c.tracks === "vertical",
      onTravel: c.onTravel,
      onTravelStart: c.onTravelStart,
      onTravelEnd: () => this.handleTravelEnd(),
    });
  }

  /**
   * Handle travel end callback.
   *
   * @private
   */
  handleTravelEnd() {
    const c = this.controller;

    c.onTravelEnd?.();

    const staging = c.stateHelper.staging;
    if (
      staging === "opening" ||
      staging === "stepping" ||
      staging === "closing"
    ) {
      c.stateHelper.advanceStaging();
    }

    if (c.stateHelper.isPositionFrontOpening()) {
      c.stateHelper.advancePosition();
      c.stackingAdapter?.notifyParentPositionMachineNext();
    } else if (c.stateHelper.isPositionFrontClosing()) {
      c.stateHelper.advancePosition();
      c.stackingAdapter?.notifyParentPositionMachineNext();
    }

    if (c.stateHelper.isOpening || c.stateHelper.isClosing) {
      c.stateHelper.completeAnimation();
    } else if (c.stateHelper.isOpen && c.stateHelper.isStagingIn("stepping")) {
      c.updateTravelStatus("idleInside");
    }
  }

  /**
   * Travel to detent after resize recalculation.
   *
   * @param {number} detentIndex - Target detent
   */
  recalculateAndTravel(detentIndex) {
    const c = this.controller;

    if (!c.scrollContainer || !c.contentWrapper || !c.dimensions) {
      return;
    }

    travelToDetent({
      destinationDetent: detentIndex,
      currentDetent: detentIndex,
      dimensions: c.dimensions,
      scrollContainer: c.scrollContainer,
      contentWrapper: c.contentWrapper,
      view: c.view,
      tracks: c.tracks,
      travelAnimations: c.travelAnimations,
      belowSheetsInStack: c.belowSheetsInStack,
      touchGestureActive: c.touchGestureActive,
      trackToTravelOn: c.tracks,
      behavior: "instant",
      runTravelCallbacksAndAnimations: false,
      runOnTravelStart: false,
      setSegment: c.setSegment,
      setProgrammaticScrollOngoing: c.setProgrammaticScrollOngoing,
      swipeOutDisabledWithDetent: c.swipeOutDisabled,
      contentPlacement: c.contentPlacement,
      hasOppositeTracks: c.tracks === "horizontal" || c.tracks === "vertical",
      snapBackAcceleratorTravelAxisSize:
        c.dimensions?.snapOutAccelerator?.travelAxis?.unitless || 0,
    });
  }

  /**
   * Travel to stuck position (first or last detent) without animation.
   *
   * @param {string} direction - "front" (last detent) or "back" (first detent)
   * @param {Function} onComplete - Callback on completion
   */
  stepToStuckPosition(direction, onComplete) {
    const c = this.controller;

    if (!c.scrollContainer || !c.dimensions?.detentMarkers) {
      return;
    }

    const lastDetent = c.dimensions.detentMarkers.length;
    const destinationDetent = direction === "front" ? lastDetent : 1;

    const overflowTimeout = CSS.supports("overscroll-behavior", "none")
      ? 1
      : 10;
    c.domAttributes?.temporarilyHideOverflow(overflowTimeout);

    travelToDetent({
      destinationDetent,
      currentDetent: c.activeDetent,
      dimensions: c.dimensions,
      scrollContainer: c.scrollContainer,
      contentWrapper: c.contentWrapper,
      view: c.view,
      tracks: c.tracks,
      travelAnimations: c.travelAnimations,
      belowSheetsInStack: c.belowSheetsInStack,
      touchGestureActive: c.touchGestureActive,
      trackToTravelOn: c.tracks,
      animationConfig: { skip: true },
      setSegment: c.setSegment,
      setProgrammaticScrollOngoing: c.setProgrammaticScrollOngoing,
      swipeOutDisabledWithDetent:
        c.dimensions?.swipeOutDisabledWithDetent ?? false,
      contentPlacement: c.contentPlacement,
      hasOppositeTracks: c.tracks === "horizontal" || c.tracks === "vertical",
      onTravelEnd: onComplete,
    });
  }
}
