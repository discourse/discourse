import { SPRING_PRESETS } from "./animation";
import { travelToDetent } from "./travel";
import { prefersReducedMotion } from "discourse/lib/utilities";

/**
 * Default animation configuration for exiting transitions.
 * Uses a stiffer spring for snappy dismiss behavior.
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
 */
const RECOGNIZED_EASINGS = new Set([
  "ease",
  "ease-in",
  "ease-out",
  "ease-in-out",
  "linear",
]);

/**
 * Manages animation travel for d-sheet component.
 * Handles animation configuration resolution and travel execution.
 */
export default class AnimationTravel {
  /**
   * @type {Object} The sheet controller instance
   */
  controller;

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
   * @private
   */
  #hasRecognizedEasing(settings, preset) {
    if (preset) {
      return true;
    }

    const easing = settings?.easing;
    if (easing === "spring") {
      return !!(settings.stiffness || settings.damping || settings.mass);
    }

    return (
      RECOGNIZED_EASINGS.has(easing) ||
      (typeof easing === "string" && easing.startsWith("cubic-bezier"))
    );
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
    const presetName = isString ? settings : settings?.preset;
    const preset = SPRING_PRESETS[presetName];

    const hasEasing = this.#hasRecognizedEasing(settings, preset);

    return {
      skip: prefersReducedMotion(),
      easing: "spring",
      ...(hasEasing ? {} : fallback),
      ...preset,
      ...(isString ? {} : settings),
    };
  }

  /**
   * Determine travel type based on current and destination detent.
   *
   * @param {number} destinationDetent - Target detent index
   * @returns {string} "entering", "exiting", or "stepping"
   */
  determineTravelType(destinationDetent) {
    if (destinationDetent === 0) {
      return "exiting";
    } else if (this.controller.activeDetent === 0) {
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
    const {
      enteringAnimationSettings,
      exitingAnimationSettings,
      steppingAnimationSettings,
    } = this.controller;

    switch (travelType) {
      case "entering":
        return enteringAnimationSettings;
      case "exiting":
        return exitingAnimationSettings;
      case "stepping":
        return steppingAnimationSettings ?? enteringAnimationSettings;
      default:
        return null;
    }
  }

  /**
   * Get fallback config for a travel type.
   *
   * @param {string} travelType - "entering", "exiting", or "stepping"
   * @returns {Object}
   * @private
   */
  #getFallbackForTravelType(travelType) {
    return travelType === "exiting"
      ? this.exitingAnimationDefaults
      : SPRING_PRESETS.smooth;
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
      (typeof settings === "object" && settings?.track) || c.tracks;

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
      swipeOutDisabledWithDetent:
        c.dimensions?.swipeOutDisabledWithDetent ?? false,
      contentPlacement: c.contentPlacement,
      hasOppositeTracks: c.tracks === "horizontal" || c.tracks === "vertical",
      snapBackAcceleratorTravelAxisSize,
      onTravel: c.onTravel,
      onTravelStart: c.onTravelStart,
      runOnTravelStart: true,
      onTravelEnd: () => this.#handleTravelEnd(),
    });
  }

  /**
   * Handle travel completion and state transitions.
   * @private
   */
  #handleTravelEnd() {
    const c = this.controller;
    const exactProgress =
      c.dimensions?.exactProgressValueAtDetents?.[c.currentSegment[0]];

    if (exactProgress !== undefined) {
      c.lastProcessedProgress = exactProgress;
      c.stackingAdapter?.updateTravelProgress(exactProgress);
    }

    c.onTravelEnd?.();

    const { animationState } = c.stateHelper;
    if (["opening", "stepping", "closing"].includes(animationState)) {
      c.stateHelper.advanceAnimation();
    }

    if (
      c.stateHelper.isPositionFrontOpening() ||
      c.stateHelper.isPositionFrontClosing()
    ) {
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
      swipeOutDisabledWithDetent:
        c.dimensions?.swipeOutDisabledWithDetent ?? false,
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

    const snapBackAcceleratorTravelAxisSize = c.edgeAlignedNoOvershoot
      ? c.snapToEndDetentsAcceleration === "auto"
        ? 10
        : 1
      : 0;

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
      swipeOutDisabledWithDetent:
        c.dimensions?.swipeOutDisabledWithDetent ?? false,
      contentPlacement: c.contentPlacement,
      hasOppositeTracks: c.tracks === "horizontal" || c.tracks === "vertical",
      snapBackAcceleratorTravelAxisSize,
      onTravelEnd: onComplete,
    });
  }
}
