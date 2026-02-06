/**
 * Orchestrates animated transitions between d-sheet detent positions.
 * Handles animation configuration resolution (presets, spring physics, fallbacks),
 * travel type detection (entering/exiting/stepping), and coordinates with the
 * sheet's state machines to ensure smooth opening, closing, and repositioning.
 * Core bridge between user gestures and the underlying travel implementation.
 */
import { prefersReducedMotion } from "discourse/lib/utilities";
import { SPRING_PRESETS } from "./animation";
import { travelToDetent } from "./travel";

/**
 * Default animation configuration for exiting transitions.
 * Uses a stiffer spring for snappy dismiss behavior.
 * @type {{ easing: string, stiffness: number, damping: number, mass: number }}
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
 * @type {Set<string>}
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
   * Calculate snap-back accelerator travel axis size.
   * @returns {number}
   * @private
   */
  #getSnapBackAcceleratorSize() {
    const c = this.controller;
    if (!c.edgeAlignedNoOvershoot) {
      return 0;
    }
    return c.snapToEndDetentsAcceleration === "auto" ? 10 : 1;
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
    const easing = settings?.easing;
    return (
      preset ||
      easing === "spring" ||
      RECOGNIZED_EASINGS.has(easing) ||
      (typeof easing === "string" && easing.startsWith("cubic-bezier"))
    );
  }

  /**
   * Resolve animation settings with fallback.
   * Merge order (later overrides earlier):
   * 1. Base { skip, easing: "spring" }
   * 2. Settings object (if not string)
   * 3. Preset values (if preset found)
   * 4. Fallback (only if no recognized easing)
   *
   * @param {string|Object|null} settings - Animation settings (preset name or config object)
   * @param {Object} fallback - Fallback config when no recognized easing
   * @returns {Object}
   * @private
   */
  #resolveAnimationSettings(settings, fallback) {
    const isString = typeof settings === "string";
    const presetName = isString ? settings : settings?.preset;
    const preset = SPRING_PRESETS[presetName];

    const hasEasing = this.#hasRecognizedEasing(settings, preset);

    return {
      skip: prefersReducedMotion(),
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
   * @private
   */
  #determineTravelType(destinationDetent) {
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
   * @private
   */
  #getRawAnimationSettings(travelType) {
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
   * @private
   */
  #getAnimationConfigForTravel(destinationDetent, travelType = null) {
    const resolvedTravelType =
      travelType ?? this.#determineTravelType(destinationDetent);
    const settings = this.#getRawAnimationSettings(resolvedTravelType);
    const fallback = this.#getFallbackForTravelType(resolvedTravelType);

    return this.#resolveAnimationSettings(settings, fallback);
  }

  /**
   * Animate sheet to a specific detent.
   *
   * @param {number} detentIndex - Target detent index
   * @param {Object} [animationConfig] - Override animation config
   * @returns {void}
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
      if (c.state.openness.isClosing && detentIndex === 0) {
        c.state.openness.completeAnimation();
        c.state.staging.advance();
      }
      if (c.state.openness.isOpening) {
        c.state.openness.completeAnimation();
        c.state.staging.advance();
      }
      return;
    }

    const travelType = this.#determineTravelType(detentIndex);
    const resolvedConfig =
      animationConfig ||
      this.#getAnimationConfigForTravel(detentIndex, travelType);

    const settings = this.#getRawAnimationSettings(travelType);
    const trackToTravelOn =
      (typeof settings === "object" && settings?.track) || c.tracks;

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
      snapBackAcceleratorTravelAxisSize: this.#getSnapBackAcceleratorSize(),
      onTravel: c.onTravel,
      onTravelStart: c.onTravelStart,
      runOnTravelStart: true,
      onTravelEnd: () => this.#handleTravelEnd(),
    });
  }

  /**
   * Handle travel completion and state transitions.
   * @returns {void}
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

    const animationState = c.state.staging.current;
    const wasOpening = c.state.openness.isOpening;
    const wasClosing = c.state.openness.isClosing;
    const wasOpen = c.state.openness.isOpen;
    const shouldAdvancePosition =
      c.state.position.isFrontOpening || c.state.position.isFrontClosing;
    const shouldAdvanceAnimation = ["opening", "stepping", "closing"].includes(
      animationState
    );
    const wasStepping = c.state.staging.matches("stepping");

    if (wasOpening || wasClosing) {
      c.state.openness.completeAnimation();
    }

    if (shouldAdvancePosition) {
      c.state.position.advance();
      c.stackingAdapter?.notifyParentPositionMachineNext();
    }

    if (shouldAdvanceAnimation) {
      c.state.staging.advance();
    }

    if (wasOpen && wasStepping) {
      c.updateTravelStatus("idleInside");
    }
  }

  /**
   * Travel to detent after resize without animation.
   *
   * @param {number} detentIndex - Target detent index
   * @returns {void}
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
   * @returns {void}
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
      swipeOutDisabledWithDetent:
        c.dimensions?.swipeOutDisabledWithDetent ?? false,
      contentPlacement: c.contentPlacement,
      hasOppositeTracks: c.tracks === "horizontal" || c.tracks === "vertical",
      snapBackAcceleratorTravelAxisSize: this.#getSnapBackAcceleratorSize(),
      onTravelEnd: onComplete,
    });
  }
}
