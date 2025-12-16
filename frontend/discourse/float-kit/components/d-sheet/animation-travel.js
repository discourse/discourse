import { SPRING_PRESETS } from "./animation";
import { travelToDetent } from "./travel";

/**
 * Default animation configuration for exiting transitions.
 * Uses a stiffer spring for snappy dismiss behavior.
 *
 * @type {Object}
 */
const EXITING_ANIMATION_DEFAULTS = {
  easing: "spring",
  stiffness: 520,
  damping: 44,
  mass: 1,
};

/**
 * Set of recognized easing types that indicate valid animation config.
 * When settings have one of these easings, fallback config is not applied.
 *
 * @type {Set<string>}
 */
const RECOGNIZED_EASINGS = new Set([
  "spring",
  "ease",
  "ease-in",
  "ease-out",
  "ease-in-out",
  "linear",
]);

/**
 * Manages animation travel for d-sheet component.
 * Handles animation configuration resolution and travel execution.
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
   * Default animation config for exiting transitions.
   *
   * @returns {Object}
   */
  get exitingAnimationDefaults() {
    return EXITING_ANIMATION_DEFAULTS;
  }

  /**
   * Check if settings have a recognized easing type.
   *
   * @param {string|Object|null} settings - Animation settings
   * @param {Object|undefined} preset - Resolved preset if any
   * @returns {boolean}
   */
  #hasRecognizedEasing(settings, preset) {
    if (preset) {
      return true;
    }
    if (settings?.easing && RECOGNIZED_EASINGS.has(settings.easing)) {
      return true;
    }
    return false;
  }

  /**
   * Resolve animation settings with fallback.
   * 1. Start with base { easing: "spring" }
   * 2. Merge settings object (if not string)
   * 3. Merge preset values (if preset found)
   * 4. Merge fallback only if no recognized easing
   *
   * @param {string|Object|null} settings - Animation settings (preset name or config object)
   * @param {Object} fallback - Fallback config when no recognized easing
   * @returns {Object}
   */
  resolveAnimationSettings(settings, fallback) {
    const isString = typeof settings === "string";
    const preset = isString
      ? SPRING_PRESETS[settings]
      : settings?.preset
        ? SPRING_PRESETS[settings.preset]
        : undefined;

    const hasEasing = this.#hasRecognizedEasing(settings, preset);

    return {
      easing: "spring",
      ...(isString ? {} : settings),
      ...(preset ?? {}),
      ...(hasEasing ? {} : fallback),
    };
  }

  /**
   * Determine travel type based on current and destination detent.
   *
   * @param {number} destinationDetent - Target detent index
   * @returns {string} "entering", "exiting", or "stepping"
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
   * Get raw animation settings for a travel type.
   * For stepping, falls back to entering settings if not specified.
   *
   * @param {string} travelType - "entering", "exiting", or "stepping"
   * @returns {string|Object|null}
   */
  getRawAnimationSettings(travelType) {
    const c = this.controller;

    switch (travelType) {
      case "entering":
        return c.enteringAnimationSettings;
      case "exiting":
        return c.exitingAnimationSettings;
      case "stepping":
        return c.steppingAnimationSettings ?? c.enteringAnimationSettings;
      default:
        return null;
    }
  }

  /**
   * Get fallback config for a travel type.
   *
   * @param {string} travelType - "entering", "exiting", or "stepping"
   * @returns {Object}
   */
  #getFallbackForTravelType(travelType) {
    if (travelType === "exiting") {
      return this.exitingAnimationDefaults;
    }
    return SPRING_PRESETS.smooth;
  }

  /**
   * Get resolved animation config for traveling to a destination detent.
   *
   * @param {number} destinationDetent - Target detent index
   * @param {string} [travelType] - Override travel type detection
   * @returns {Object}
   */
  getAnimationConfigForTravel(destinationDetent, travelType = null) {
    const resolvedTravelType =
      travelType ?? this.determineTravelType(destinationDetent);
    const settings = this.getRawAnimationSettings(resolvedTravelType);
    const fallback = this.#getFallbackForTravelType(resolvedTravelType);

    return this.resolveAnimationSettings(settings, fallback);
  }

  /**
   * Animate sheet to a specific detent.
   *
   * @param {number} detentIndex - Target detent index
   * @param {Object} [animationConfig] - Override animation config
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

    const settings = this.getRawAnimationSettings(travelType);
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
      onTravelEnd: () => this.#handleTravelEnd(),
    });
  }

  /**
   * Handle travel completion and state transitions.
   */
  #handleTravelEnd() {
    const c = this.controller;

    const exactProgress =
      c.dimensions?.exactProgressValueAtDetents?.[c.currentSegment[0]];
    if (exactProgress !== undefined) {
      c.lastProcessedProgress = exactProgress;
    }

    c.onTravelEnd?.();

    const animationState = c.stateHelper.animationState;
    if (
      animationState === "opening" ||
      animationState === "stepping" ||
      animationState === "closing"
    ) {
      c.stateHelper.advanceAnimationState();
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
    } else if (
      c.stateHelper.isOpen &&
      c.stateHelper.isInAnimationState("stepping")
    ) {
      c.updateTravelStatus("idleInside");
    }
  }

  /**
   * Travel to detent after resize without animation.
   *
   * @param {number} detentIndex - Target detent index
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
   * Travel to stuck position (first or last detent) instantly.
   *
   * @param {string} direction - "front" for last detent, "back" for first
   * @param {Function} onComplete - Callback when travel completes
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
