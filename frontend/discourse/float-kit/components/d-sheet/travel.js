import {
  createTweenFunction,
  generateAnimationConfig,
  supportsLinearEasing,
} from "./animation";

/**
 * Wraps a callback-based function as a Promise.
 *
 * @param {Function} callbackFn - Function that accepts a callback as its only argument
 * @returns {Promise<void>}
 */
function wrapAsPromise(callbackFn) {
  return new Promise((resolve) => {
    callbackFn(() => resolve());
  });
}

/** @type {string[]} CSS transform properties */
const TRANSFORM_PROPS = [
  "translate",
  "translateX",
  "translateY",
  "translateZ",
  "scale",
  "scaleX",
  "scaleY",
  "scaleZ",
  "rotate",
  "rotateX",
  "rotateY",
  "rotateZ",
  "skew",
  "skewX",
  "skewY",
];

/**
 * Builds a single keyframe object from config at a given progress.
 *
 * @param {Object} config - Animation config with property template functions
 * @param {number} progress - Progress value
 * @returns {Object} Keyframe object for Web Animations API
 */
function buildKeyframe(config, progress) {
  const keyframe = {};
  const transforms = [];
  const tween = createTweenFunction(progress);

  for (const [property, value] of Object.entries(config)) {
    if (
      value === null ||
      value === undefined ||
      property === "transformOrigin"
    ) {
      continue;
    }

    let computedValue;
    if (Array.isArray(value)) {
      computedValue = tween(value[0], value[1]);
    } else if (typeof value === "function") {
      computedValue = value({ progress, tween });
    } else if (typeof value === "string") {
      computedValue = value;
    } else {
      continue;
    }

    if (TRANSFORM_PROPS.includes(property)) {
      transforms.push(`${property}(${computedValue})`);
    } else {
      keyframe[property] = computedValue;
    }
  }

  if (transforms.length > 0) {
    keyframe.transform = transforms.join(" ");
  }

  return keyframe;
}

/**
 * Converts a camelCase CSS property to kebab-case with vendor prefix handling.
 *
 * @param {string} property - camelCase property name
 * @returns {string} kebab-case property name
 */
function toKebabCase(property) {
  const prefix =
    property.startsWith("webkit") || property.startsWith("moz") ? "-" : "";
  return prefix + property.replace(/[A-Z]/g, "-$&").toLowerCase();
}

/**
 * Builds keyframes array from config and progress values.
 *
 * @param {Object} config - Animation config
 * @param {number[]} progressValues - Array of progress values
 * @param {boolean} supportsLinear - Whether linear() easing is supported
 * @param {Object|null} [stackingInfo] - Stacking info with reversedStackingIndex and selfAndAboveTravelProgressSum
 * @returns {Object[]} Array of keyframe objects
 */
function buildKeyframesFromConfig(
  config,
  progressValues,
  supportsLinear,
  stackingInfo = null
) {
  const adjustProgress = (progress) => {
    if (!stackingInfo) {
      return progress;
    }
    const { reversedStackingIndex, selfAndAboveTravelProgressSum } =
      stackingInfo;
    if (selfAndAboveTravelProgressSum && reversedStackingIndex !== undefined) {
      return (
        (selfAndAboveTravelProgressSum[reversedStackingIndex] ?? 0) + progress
      );
    }
    return progress;
  };

  if (supportsLinear) {
    return [
      buildKeyframe(config, adjustProgress(progressValues[0])),
      buildKeyframe(
        config,
        adjustProgress(progressValues[progressValues.length - 1])
      ),
    ];
  }
  return progressValues.map((p) => buildKeyframe(config, adjustProgress(p)));
}

/**
 * Animates a single target element and returns a promise that resolves when complete.
 * Persists final keyframe styles to the element after animation finishes.
 *
 * @param {Object} params - Animation parameters
 * @param {HTMLElement} params.target - Element to animate
 * @param {Object[]} params.keyframes - Keyframes array
 * @param {Object} params.animationOptions - WAAPI animation options
 * @param {string} [params.transformOrigin] - Optional transform origin
 * @returns {Promise<void>}
 */
function animateTarget({
  target,
  keyframes,
  animationOptions,
  transformOrigin,
}) {
  if (transformOrigin) {
    target.style.transformOrigin = transformOrigin;
  }

  const animation = target.animate(keyframes, animationOptions);

  return new Promise((resolve) => {
    animation.addEventListener("finish", function onFinish() {
      const finalKeyframe = keyframes[keyframes.length - 1];
      if (finalKeyframe) {
        Object.entries(finalKeyframe).forEach(([property, value]) => {
          target.style.setProperty(toKebabCase(property), value);
        });
      }
      animation.removeEventListener("finish", onFinish);
      resolve();
    });
  });
}

/**
 * Resolves the destination detent, using active detent as fallback.
 * @param {number|undefined} desiredDetent - Desired detent index
 * @param {number} activeDetent - Current active detent index
 * @returns {number} Resolved detent index
 */
export function resolveDestinationDetent(desiredDetent, activeDetent) {
  return typeof desiredDetent === "number" ? desiredDetent : activeDetent;
}

/**
 * Calculates the scroll position needed to reach a specific detent.
 *
 * @param {Object} config - Configuration object
 * @param {string} config.trackToTravelOn - Track direction (top, bottom, left, right, horizontal, vertical)
 * @param {number} config.destinationDetent - Target detent index
 * @param {number} config.detentCount - Total number of detents
 * @param {boolean} config.swipeOutDisabled - Whether swipe-out is disabled
 * @param {boolean} config.hasOppositeTracks - Whether sheet has opposite tracks
 * @param {string} config.contentPlacement - Content placement (center or edge)
 * @param {Object} config.elementsDimensions - Dimensions of sheet elements
 * @param {number} [config.snapBackAcceleratorSize] - Size of snap-back accelerator
 * @returns {{positionToScrollTo: number|null, scrollAxis: string|null}} Scroll position and axis
 */
export function calculateScrollPositionForDetent(config) {
  const {
    trackToTravelOn,
    destinationDetent,
    detentCount,
    swipeOutDisabled,
    hasOppositeTracks,
    contentPlacement,
    elementsDimensions,
    snapBackAcceleratorSize,
  } = config;

  if (elementsDimensions.detentMarkers?.length <= destinationDetent - 1) {
    return {
      positionToScrollTo: null,
      scrollAxis: null,
    };
  }

  const isClosedDetent = destinationDetent === 0;
  const isFirstDetent = destinationDetent === 1;
  const isLastDetent = destinationDetent === detentCount;
  const isBackTrack =
    trackToTravelOn === "right" || trackToTravelOn === "bottom";

  const viewSize = elementsDimensions.view.travelAxis.unitless;
  const contentSize = elementsDimensions.content.travelAxis.unitless;
  const acceleratorSize =
    elementsDimensions.snapOutAccelerator.travelAxis.unitless;
  const detentMarkers = elementsDimensions.detentMarkers;
  const detentOffset = isClosedDetent
    ? 0
    : detentMarkers[destinationDetent - 1].accumulatedOffsets.travelAxis
        .unitless;

  let scrollPosition = 0;

  if (hasOppositeTracks) {
    if (isLastDetent) {
      scrollPosition =
        viewSize -
        (viewSize - contentSize) / 2 +
        elementsDimensions.snapOutAccelerator.travelAxis.unitless;
    } else if (isClosedDetent) {
      scrollPosition = isBackTrack ? 0 : 10000;
    }
  } else if (isBackTrack) {
    if (isLastDetent) {
      scrollPosition = 10000;
    } else if ((swipeOutDisabled && isFirstDetent) || isClosedDetent) {
      scrollPosition = 0;
    } else if (
      !isLastDetent &&
      !(swipeOutDisabled && isFirstDetent) &&
      !isClosedDetent
    ) {
      if (swipeOutDisabled) {
        scrollPosition =
          detentMarkers[destinationDetent - 1].accumulatedOffsets.travelAxis
            .unitless - detentMarkers[0].travelAxis.unitless;
      } else {
        scrollPosition = detentOffset + acceleratorSize;
      }
    }
  } else if (trackToTravelOn === "left" || trackToTravelOn === "top") {
    const effectiveAcceleratorSize = snapBackAcceleratorSize ?? acceleratorSize;
    const acceleratorAdjustment =
      swipeOutDisabled && isFirstDetent
        ? 2 * effectiveAcceleratorSize
        : isLastDetent
          ? 0
          : effectiveAcceleratorSize;

    if (contentPlacement === "center") {
      scrollPosition = isClosedDetent
        ? contentSize +
          (viewSize - contentSize) / 2 -
          detentOffset +
          acceleratorAdjustment
        : 0;
    } else {
      scrollPosition = contentSize - detentOffset + acceleratorAdjustment;
    }
  }

  return {
    positionToScrollTo: scrollPosition,
    scrollAxis:
      trackToTravelOn === "left" ||
      trackToTravelOn === "right" ||
      trackToTravelOn === "horizontal"
        ? "x"
        : "y",
  };
}

/**
 * Executes animated sheet travel to a destination detent using Web Animations API.
 * @param {Object} config - Configuration object
 * @param {number} config.destinationDetent - Target detent index
 * @param {Function} config.setSegment - Function to update current segment
 * @param {HTMLElement} config.view - View element
 * @param {HTMLElement} config.scrollContainer - Scroll container element
 * @param {HTMLElement} config.contentWrapper - Content wrapper element
 * @param {Array} config.travelAnimations - Array of travel animation callbacks
 * @param {Array} config.belowSheetsInStack - Sheets below in the stack
 * @param {string} config.contentPlacement - Content placement
 * @param {number} config.positionToScrollTo - Target scroll position
 * @param {string} config.scrollAxis - Scroll axis (x or y)
 * @param {Object} config.animationConfig - Animation configuration
 * @param {Function} [config.onTravel] - Callback during travel
 * @param {Function} [config.onTravelStart] - Callback at travel start
 * @param {Function} [config.onTravelEnd] - Callback at travel end
 * @param {boolean} [config.runOnTravelStart] - Whether to run onTravelStart
 * @param {Function} [config.rAFLoopEndCallback] - RAF loop end callback
 * @param {Object} config.dimensions - Sheet dimensions
 * @param {string} config.trackToTravelOn - Track direction
 */
export function executeSheetTravel(config) {
  const {
    destinationDetent,
    setSegment,
    view,
    scrollContainer,
    contentWrapper,
    travelAnimations,
    belowSheetsInStack,
    contentPlacement,
    positionToScrollTo,
    scrollAxis,
    animationConfig,
    onTravel,
    onTravelStart,
    onTravelEnd,
    runOnTravelStart,
    rAFLoopEndCallback,
    dimensions,
    trackToTravelOn,
  } = config;

  const stackingAnimations = [];

  belowSheetsInStack.forEach((belowSheet) => {
    stackingAnimations.push(
      ...belowSheet.stackingAnimations.map((anim) => ({
        ...anim,
        reversedStackingIndex: belowSheetsInStack.length - 1,
        selfAndAboveTravelProgressSum: belowSheet.selfAndAboveTravelProgressSum,
      }))
    );
  });

  if (runOnTravelStart && onTravelStart) {
    onTravelStart();
  }

  const shouldAnimateContent =
    !Object.hasOwn(animationConfig, "contentMove") ||
    animationConfig.contentMove;

  const viewTravelSize = dimensions.view.travelAxis.unitless;
  const contentTravelSize = dimensions.content.travelAxis.unitless;
  const effectiveContentSize =
    contentPlacement !== "center"
      ? contentTravelSize
      : contentTravelSize + (viewTravelSize - contentTravelSize) / 2;

  const viewRect = view.getBoundingClientRect();
  const contentWrapperRect = contentWrapper.getBoundingClientRect();
  const verticalOffset = contentWrapperRect.top - viewRect.top;
  const horizontalOffset = contentWrapperRect.left - viewRect.left;

  let currentOffset = 0;
  switch (trackToTravelOn) {
    case "top":
      currentOffset = verticalOffset + effectiveContentSize;
      break;
    case "bottom":
      currentOffset = verticalOffset - effectiveContentSize;
      break;
    case "left":
      currentOffset = horizontalOffset + effectiveContentSize;
      break;
    case "right":
      currentOffset = horizontalOffset - effectiveContentSize;
      break;
  }

  const currentProgress = Math.max(
    Math.abs(currentOffset) / effectiveContentSize,
    0
  );

  const targetProgress =
    dimensions.progressValueAtDetents[destinationDetent].exact;
  const progressDelta = targetProgress - currentProgress;

  const targetPosition = targetProgress * effectiveContentSize;
  const targetOffset =
    trackToTravelOn === "left" || trackToTravelOn === "top"
      ? targetPosition
      : -targetPosition;

  const animation = generateAnimationConfig({
    origin: currentOffset,
    destination: targetOffset,
    animationConfig,
  });

  const { progressValuesArray, duration, delay } = animation;

  const filteredProgressValues = [];
  for (let i = 0; i < progressValuesArray.length - 1; i += 8) {
    filteredProgressValues.push(progressValuesArray[i]);
  }
  if (progressValuesArray.length % 8 !== 0) {
    filteredProgressValues.push(
      progressValuesArray[progressValuesArray.length - 1]
    );
  }

  const mappedProgressValues = filteredProgressValues.map(
    (e) => currentProgress + progressDelta * e
  );

  const finalScrollPosition = positionToScrollTo;

  const transformAxis = scrollAxis === "x" ? "X" : "Y";

  const transformDistance = currentOffset - targetOffset;

  const needsTransform =
    shouldAnimateContent &&
    !Number.isNaN(transformDistance) &&
    transformDistance !== 0;

  const useLinearEasing = supportsLinearEasing();
  const easingValue = useLinearEasing
    ? `linear(${filteredProgressValues.join(",")})`
    : "linear";

  const transformKeyframes = needsTransform
    ? useLinearEasing
      ? [
          {
            transform: `translate${transformAxis}(${transformDistance * (1 - filteredProgressValues[0])}px)`,
          },
          {
            transform: `translate${transformAxis}(${transformDistance * (1 - filteredProgressValues[filteredProgressValues.length - 1])}px)`,
          },
        ]
      : filteredProgressValues.map((progressValue) => ({
          transform: `translate${transformAxis}(${transformDistance * (1 - progressValue)}px)`,
        }))
    : [{ transform: "translateY(0px)" }, { transform: "translateY(0px)" }];

  const setScroll = () => {
    if (scrollAxis === "x") {
      scrollContainer.scrollTo({
        left: finalScrollPosition,
        top: 0,
      });
      scrollContainer.scrollLeft = finalScrollPosition;
    } else {
      scrollContainer.scrollTo({
        left: 0,
        top: finalScrollPosition,
      });
      scrollContainer.scrollTop = finalScrollPosition;
    }
  };

  const animateContent = (callback) => {
    if (!needsTransform || !contentWrapper) {
      callback();
      return;
    }

    const contentAnimation = contentWrapper.animate(transformKeyframes, {
      duration,
      easing: easingValue,
      delay,
    });

    contentAnimation.addEventListener("finish", () => {
      callback();
    });
  };

  const animateTravelCallbacks = (callback) => {
    if (!travelAnimations.length && !stackingAnimations.length && !onTravel) {
      callback();
      return;
    }

    const animationOptions = { duration, easing: easingValue, delay };
    const progressValues = useLinearEasing
      ? [
          mappedProgressValues[0],
          mappedProgressValues[mappedProgressValues.length - 1],
        ]
      : mappedProgressValues;

    const allAnimationPromises = [];

    travelAnimations
      .filter((anim) => anim.config && anim.target)
      .forEach((anim) => {
        const keyframes = buildKeyframesFromConfig(
          anim.config,
          progressValues,
          useLinearEasing
        );
        allAnimationPromises.push(
          animateTarget({
            target: anim.target,
            keyframes,
            animationOptions,
            transformOrigin: anim.config.transformOrigin,
          })
        );
      });

    stackingAnimations
      .filter((anim) => anim.config && anim.target)
      .forEach((anim) => {
        const keyframes = buildKeyframesFromConfig(
          anim.config,
          progressValues,
          useLinearEasing,
          {
            reversedStackingIndex: anim.reversedStackingIndex,
            selfAndAboveTravelProgressSum: anim.selfAndAboveTravelProgressSum,
          }
        );
        allAnimationPromises.push(
          animateTarget({
            target: anim.target,
            keyframes,
            animationOptions,
            transformOrigin: anim.config.transformOrigin,
          })
        );
      });

    let startTime = null;

    const progressReportLoop = (timestamp) => {
      if (startTime === null) {
        startTime = timestamp;
      }

      const elapsed = timestamp - startTime;
      const frameIndex = Math.floor(elapsed);

      if (frameIndex < progressValuesArray.length) {
        const progress =
          currentProgress + progressDelta * progressValuesArray[frameIndex];

        let currentSegment = [0, 0];
        if (progress < 0) {
          currentSegment = [0, 0];
          setSegment(currentSegment);
        } else if (progress > 1) {
          currentSegment = [1, 1];
          setSegment(currentSegment);
        } else if (dimensions?.progressValueAtDetents) {
          const detents = dimensions.progressValueAtDetents;
          for (let i = 0; i < detents.length; i++) {
            const detent = detents[i];
            if (
              progress > detent.after &&
              i + 1 < detents.length &&
              progress < detents[i + 1].before
            ) {
              currentSegment = [i, i + 1];
              setSegment(currentSegment);
            } else if (progress > detent.before && progress < detent.after) {
              currentSegment = [i, i];
              setSegment(currentSegment);
            }
          }
        }

        if (onTravel) {
          onTravel({
            progress,
            range: { start: currentSegment[0], end: currentSegment[1] },
            progressAtDetents: dimensions.exactProgressValueAtDetents,
          });
        }

        requestAnimationFrame(progressReportLoop);
      } else {
        const lastDetent = Math.min(
          (dimensions?.progressValueAtDetents?.length ?? 1) - 1,
          destinationDetent
        );
        setSegment([lastDetent, lastDetent]);

        Promise.all(allAnimationPromises).then(() => {
          callback();
        });
      }
    };

    if (onTravel || dimensions?.progressValueAtDetents) {
      requestAnimationFrame(progressReportLoop);
    } else {
      Promise.all(allAnimationPromises).then(() => {
        callback();
      });
    }
  };

  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      if (view?.dataset?.dSheet?.includes("hidden")) {
        view.dataset.dSheet = view.dataset.dSheet
          .replace(/\s*hidden\s*/g, " ")
          .trim();
      }

      setScroll();

      Promise.all([
        wrapAsPromise(animateContent),
        wrapAsPromise(animateTravelCallbacks),
      ]).then(() => {
        if (onTravelEnd) {
          onTravelEnd();
        }
        if (rAFLoopEndCallback) {
          rAFLoopEndCallback();
        }
      });
    });
  });
}

/**
 * Main entry point for traveling to a detent. Handles both smooth and instant behavior.
 * @param {Object} config - Configuration object
 * @param {number} [config.destinationDetent] - Target detent index
 * @param {number} config.currentDetent - Current detent index
 * @param {Object} config.dimensions - Sheet dimensions
 * @param {HTMLElement} config.scrollContainer - Scroll container element
 * @param {HTMLElement} config.contentWrapper - Content wrapper element
 * @param {HTMLElement} config.view - View element
 * @param {string} config.tracks - Track direction
 * @param {Array} config.travelAnimations - Array of travel animation callbacks
 * @param {Array} config.belowSheetsInStack - Sheets below in the stack
 * @param {string} [config.trackToTravelOn] - Track to travel on (overrides tracks)
 * @param {boolean} [config.runTravelCallbacksAndAnimations=true] - Whether to run callbacks
 * @param {boolean} [config.runOnTravelStart=true] - Whether to run onTravelStart
 * @param {Object} config.animationConfig - Animation configuration
 * @param {Function} [config.rAFLoopEndCallback] - RAF loop end callback
 * @param {Function} [config.onTravel] - Callback during travel
 * @param {Function} [config.onTravelStart] - Callback at travel start
 * @param {Function} [config.onTravelEnd] - Callback at travel end
 * @param {Array} config.segment - Current segment
 * @param {Function} [config.fullTravelCallback] - Full travel callback
 * @param {number} [config.snapBackAcceleratorTravelAxisSize] - Snap-back accelerator size
 * @param {boolean} config.swipeOutDisabledWithDetent - Whether swipe-out is disabled
 * @param {Function} config.setSegment - Function to update segment
 * @param {Function} [config.setProgrammaticScrollOngoing] - Function to set programmatic scroll flag
 * @param {string} config.contentPlacement - Content placement
 * @param {boolean} config.hasOppositeTracks - Whether sheet has opposite tracks
 * @param {string} [config.behavior] - Travel behavior (smooth or instant)
 */
export function travelToDetent(config) {
  const {
    destinationDetent,
    currentDetent,
    dimensions,
    scrollContainer,
    contentWrapper,
    view,
    tracks,
    travelAnimations,
    belowSheetsInStack,
    trackToTravelOn,
    runTravelCallbacksAndAnimations = true,
    runOnTravelStart = true,
    animationConfig,
    rAFLoopEndCallback,
    onTravel,
    onTravelStart,
    onTravelEnd,
    segment,
    fullTravelCallback,
    snapBackAcceleratorTravelAxisSize,
    swipeOutDisabledWithDetent,
    setSegment,
    setProgrammaticScrollOngoing,
    contentPlacement,
    hasOppositeTracks,
  } = config;

  if (destinationDetent === undefined && currentDetent === null) {
    return;
  }

  if (!scrollContainer || !dimensions?.content) {
    return;
  }

  const resolvedDestination = resolveDestinationDetent(
    destinationDetent,
    currentDetent
  );

  const trackToTravelOnResolved = trackToTravelOn || tracks;

  const scrollInfo = calculateScrollPositionForDetent({
    destinationDetent: resolvedDestination,
    detentCount: dimensions.detentMarkers.length,
    trackToTravelOn: trackToTravelOnResolved,
    swipeOutDisabled: swipeOutDisabledWithDetent,
    hasOppositeTracks,
    contentPlacement,
    snapBackAcceleratorSize: snapBackAcceleratorTravelAxisSize,
    elementsDimensions: dimensions,
  });

  const { positionToScrollTo, scrollAxis } = scrollInfo;

  if (positionToScrollTo === null || scrollAxis === null) {
    return;
  }

  if (setProgrammaticScrollOngoing) {
    setProgrammaticScrollOngoing(true);
  }

  const behavior =
    config.behavior || (animationConfig?.skip ? "instant" : "smooth");

  if (behavior === "smooth") {
    executeSheetTravel({
      destinationDetent: resolvedDestination,
      setSegment,
      view,
      scrollContainer,
      contentWrapper,
      travelAnimations,
      belowSheetsInStack,
      positionToScrollTo,
      contentPlacement,
      scrollAxis,
      animationConfig,
      onTravel,
      onTravelStart,
      onTravelEnd,
      runOnTravelStart,
      rAFLoopEndCallback,
      dimensions,
      trackToTravelOn: trackToTravelOnResolved,
    });
  } else {
    if (runTravelCallbacksAndAnimations && runOnTravelStart && onTravelStart) {
      onTravelStart();
    }

    if (scrollAxis === "x") {
      scrollContainer.scrollTo(positionToScrollTo, 0);
      scrollContainer.scrollLeft = positionToScrollTo;
    } else {
      scrollContainer.scrollTo(0, positionToScrollTo);
      scrollContainer.scrollTop = positionToScrollTo;
    }

    setSegment([resolvedDestination, resolvedDestination]);

    if (runTravelCallbacksAndAnimations) {
      const targetProgress =
        dimensions.progressValueAtDetents[resolvedDestination].exact;
      if (fullTravelCallback) {
        fullTravelCallback(targetProgress, segment);
      }
      if (onTravelEnd) {
        onTravelEnd();
      }
    }
  }
}
