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
   * Determine the travel type based on current and destination detent.
   *
   * @param {number} destinationDetent - Target detent index
   * @returns {string} Travel type: "entering", "exiting", or "stepping"
   */
  determineTravelType(destinationDetent) {
    const c = this.controller;

    if (destinationDetent === 0) {
      return "exiting";
    } else if (c.activeDetent === 0) {
      return "entering";
    }
    return "stepping";
  }

  /**
   * Get the raw animation settings for a travel type.
   *
   * @param {string} travelType - Type of travel: "entering", "exiting", or "stepping"
   * @returns {string|Object|null}
   */
  getAnimationSettingsForTravelType(travelType) {
    const c = this.controller;

    switch (travelType) {
      case "entering":
        return c.enteringAnimationSettings;
      case "exiting":
        return c.exitingAnimationSettings;
      case "stepping":
        return c.steppingAnimationSettings;
      default:
        return null;
    }
  }

  /**
   * Get animation config for a travel to a destination detent.
   *
   * @param {number} destinationDetent - Target detent index
   * @param {string} [travelType] - Type of travel: "entering", "exiting", or "stepping"
   * @returns {Object}
   */
  getAnimationConfigForTravel(destinationDetent, travelType = null) {
    if (!travelType) {
      travelType = this.determineTravelType(destinationDetent);
    }

    const settings = this.getAnimationSettingsForTravelType(travelType);
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

    const travelType = this.determineTravelType(detentIndex);
    const resolvedConfig =
      animationConfig ||
      this.getAnimationConfigForTravel(detentIndex, travelType);

    const settings = this.getAnimationSettingsForTravelType(travelType);
    const trackToTravelOn =
      (settings && typeof settings === "object" && settings.track) || c.tracks;

    const snapBackAcceleratorTravelAxisSize = c.edgeAlignedNoOvershoot
      ? c.snapToEndDetentsAcceleration === "auto"
        ? 10
        : 1
      : 0;

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
      trackToTravelOn,
      animationConfig: resolvedConfig,
      setSegment: c.setSegment,
      setProgrammaticScrollOngoing: c.setProgrammaticScrollOngoing,
      swipeOutDisabledWithDetent:
        c.dimensions?.swipeOutDisabledWithDetent ?? false,
      contentPlacement: c.contentPlacement,
      hasOppositeTracks: c.tracks === "horizontal" || c.tracks === "vertical",
      snapBackAcceleratorTravelAxisSize,
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

    const exactProgress =
      c.dimensions?.exactProgressValueAtDetents?.[c.currentSegment[0]];
    if (exactProgress !== undefined) {
      c.lastProcessedProgress = exactProgress;
    }

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
