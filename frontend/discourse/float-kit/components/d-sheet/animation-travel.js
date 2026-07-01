import { prefersReducedMotion } from "discourse/lib/utilities";
import { SPRING_PRESETS } from "./animation";
import { travelToDetent } from "./travel";

const EXITING_ANIMATION_DEFAULTS = {
  easing: "spring",
  stiffness: 520,
  damping: 44,
  mass: 1,
};
const RECOGNIZED_EASINGS = new Set([
  "ease",
  "ease-in",
  "ease-out",
  "ease-in-out",
  "linear",
]);

export default class AnimationTravel {
  controller;

  constructor(controller) {
    this.controller = controller;
  }

  get exitingAnimationDefaults() {
    return EXITING_ANIMATION_DEFAULTS;
  }

  #getSnapBackAcceleratorSize() {
    const c = this.controller;
    if (!c.edgeAlignedNoOvershoot) {
      return 0;
    }
    return c.snapToEndDetentsAcceleration === "auto" ? 10 : 1;
  }

  #hasRecognizedEasing(settings, preset) {
    const easing = settings?.easing;
    return (
      preset ||
      easing === "spring" ||
      RECOGNIZED_EASINGS.has(easing) ||
      (typeof easing === "string" && easing.startsWith("cubic-bezier"))
    );
  }

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

  #determineTravelType(destinationDetent) {
    if (destinationDetent === 0) {
      return "exiting";
    } else if (this.controller.activeDetent === 0) {
      return "entering";
    }
    return "stepping";
  }

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

  #getFallbackForTravelType(travelType) {
    return travelType === "exiting"
      ? this.exitingAnimationDefaults
      : SPRING_PRESETS.smooth;
  }

  #getAnimationConfigForTravel(destinationDetent, travelType = null) {
    const resolvedTravelType =
      travelType ?? this.#determineTravelType(destinationDetent);
    const settings = this.#getRawAnimationSettings(resolvedTravelType);
    const fallback = this.#getFallbackForTravelType(resolvedTravelType);

    return this.#resolveAnimationSettings(settings, fallback);
  }

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
      if (c.state.position.isFrontOpening || c.state.position.isFrontClosing) {
        c.state.position.advance();
        c.stackingAdapter?.notifyParentPositionMachineNext();
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
