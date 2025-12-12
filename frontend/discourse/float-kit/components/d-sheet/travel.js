import { generateAnimationConfig, supportsLinearEasing } from "./animation";

/**
 * Interpolates between two values based on progress.
 * @param {string|number} start - Start value
 * @param {string|number} end - End value
 * @param {number} progress - Progress value between 0 and 1
 * @returns {string|number} Interpolated value
 */
function tween(start, end, progress) {
  const startNum = typeof start === "string" ? parseFloat(start) : start;
  const endNum = typeof end === "string" ? parseFloat(end) : end;
  const unit = typeof start === "string" ? start.replace(/[\d.-]/g, "") : "";
  return startNum + (endNum - startNum) * Math.min(progress, 1) + unit;
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
 * @param {Object} config - Animation config with property values
 * @param {number} progress - Progress value
 * @returns {Object} Keyframe object for Web Animations API
 */
function buildKeyframe(config, progress) {
  const keyframe = {};
  const transforms = [];

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
      computedValue = tween(value[0], value[1], progress);
    } else if (typeof value === "function") {
      computedValue = value({
        progress,
        tween: (s, e) => tween(s, e, progress),
      });
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
 * Builds keyframes array from config and progress values.
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
 * @param {Object} config - Configuration object
 * @param {string} config.trackToTravelOn - Track direction (top, bottom, left, right, horizontal, vertical)
 * @param {number} config.destinationDetent - Target detent index
 * @param {number} config.detentCount - Total number of detents
 * @param {boolean} config.swipeOutDisabled - Whether swipe-out is disabled
 * @param {boolean} config.hasOppositeTracks - Whether sheet has opposite tracks
 * @param {string} config.contentPlacement - Content placement (center or edge)
 * @param {Object} config.elementsDimensions - Dimensions of sheet elements
 * @param {number} [config.snapBackAcceleratorSize] - Size of snap-back accelerator
 * @param {number} config.scrollContainerClientHeight - Client height of scroll container
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
    scrollContainerClientHeight,
  } = config;

  const hasNoMarkers = !elementsDimensions.detentMarkers?.length;

  if (
    !hasNoMarkers &&
    elementsDimensions.detentMarkers.length <= destinationDetent - 1
  ) {
    return {
      positionToScrollTo: null,
      scrollAxis: null,
    };
  }

  if (hasNoMarkers && destinationDetent > 1) {
    return {
      positionToScrollTo: null,
      scrollAxis: null,
    };
  }

  const effectiveDetentCount = hasNoMarkers ? 1 : detentCount;
  const isClosedDetent = destinationDetent === 0;
  const isFirstDetent = destinationDetent === 1;
  const isLastDetent = destinationDetent === effectiveDetentCount;
  const isBackTrack =
    trackToTravelOn === "right" ||
    trackToTravelOn === "bottom" ||
    trackToTravelOn === "horizontal" ||
    trackToTravelOn === "vertical";

  const viewSize = elementsDimensions.view.travelAxis.unitless;
  const contentSize = elementsDimensions.content.travelAxis.unitless;
  const acceleratorSize =
    elementsDimensions.snapOutAccelerator?.travelAxis?.unitless ?? 1;

  const detentMarkers = elementsDimensions.detentMarkers;
  const markerIndex = Math.min(destinationDetent - 1, detentCount - 1);
  const detentOffset =
    isClosedDetent || isLastDetent
      ? 0
      : (detentMarkers[markerIndex]?.accumulatedOffsets?.travelAxis?.unitless ??
        0);

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
    } else if (isFirstDetent && !isClosedDetent) {
      scrollPosition = detentOffset + acceleratorSize;
    } else {
      if (swipeOutDisabled) {
        const marker = detentMarkers[markerIndex];
        scrollPosition =
          (marker?.accumulatedOffsets?.travelAxis?.unitless ?? 0) -
          (detentMarkers[0]?.travelAxis?.unitless ?? 0);
      } else {
        const frontSpacerSize =
          elementsDimensions.frontSpacer?.travelAxis?.unitless ??
          scrollContainerClientHeight - viewSize;
        scrollPosition = frontSpacerSize + detentOffset;
      }
    }
  } else if (trackToTravelOn === "left" || trackToTravelOn === "top") {
    const effectiveAcceleratorSize =
      snapBackAcceleratorSize ??
      elementsDimensions.snapOutAccelerator?.travelAxis?.unitless ??
      acceleratorSize;

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
    } else if (isLastDetent) {
      scrollPosition = 0;
    } else if (isClosedDetent) {
      scrollPosition = contentSize + acceleratorAdjustment;
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
    touchGestureActive,
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

  let needsTransform =
    shouldAnimateContent &&
    !Number.isNaN(transformDistance) &&
    transformDistance !== 0;

  const useLinearEasing = supportsLinearEasing();

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
        behavior: "instant",
      });
      scrollContainer.scrollLeft = finalScrollPosition;
    } else {
      scrollContainer.scrollTo({
        left: 0,
        top: finalScrollPosition,
        behavior: "instant",
      });
      scrollContainer.scrollTop = finalScrollPosition;
    }
  };

  const animateContent = (callback) => {
    if (!needsTransform || !contentWrapper) {
      callback();
      return;
    }

    const easingValue = useLinearEasing
      ? `linear(${filteredProgressValues.join(",")})`
      : "linear";

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
    if (!travelAnimations.length && !stackingAnimations.length) {
      callback();
      return;
    }

    const initialProgress = mappedProgressValues[0];
    for (let i = 0; i < travelAnimations.length; i++) {
      travelAnimations[i].callback(initialProgress);
    }

    const useLinearEasingForStacking = supportsLinearEasing();
    const easingValue = useLinearEasingForStacking
      ? `linear(${filteredProgressValues.join(",")})`
      : "linear";

    const stackingAnimationPromises = [];
    stackingAnimations
      .filter((anim) => anim.config && anim.target)
      .forEach((anim) => {
        const stackingProgressValues = useLinearEasingForStacking
          ? [
              mappedProgressValues[0],
              mappedProgressValues[mappedProgressValues.length - 1],
            ]
          : mappedProgressValues;
        const keyframes = buildKeyframesFromConfig(
          anim.config,
          stackingProgressValues,
          useLinearEasingForStacking,
          {
            reversedStackingIndex: anim.reversedStackingIndex,
            selfAndAboveTravelProgressSum: anim.selfAndAboveTravelProgressSum,
          }
        );

        if (anim.config.transformOrigin) {
          anim.target.style.transformOrigin = anim.config.transformOrigin;
        }

        const stackingAnim = anim.target.animate(keyframes, {
          duration,
          easing: easingValue,
          delay,
        });

        const promise = new Promise((resolve) => {
          stackingAnim.addEventListener("finish", function onFinish() {
            const finalKeyframe = keyframes[keyframes.length - 1];
            if (finalKeyframe) {
              Object.entries(finalKeyframe).forEach(([property, value]) => {
                const kebabProperty =
                  (property.startsWith("webkit") || property.startsWith("moz")
                    ? "-"
                    : "") + property.replace(/[A-Z]/g, "-$&").toLowerCase();
                anim.target.style.setProperty(kebabProperty, value);
              });
            }
            stackingAnim.removeEventListener("finish", onFinish);
            resolve();
          });
        });
        stackingAnimationPromises.push(promise);
      });

    let startTime = null;
    let frameIndex = 0;

    const callbackLoop = (timestamp) => {
      if (startTime === null) {
        startTime = timestamp;
      }

      const elapsed = timestamp - startTime;
      frameIndex = Math.floor(elapsed);

      if (frameIndex < progressValuesArray.length) {
        const progress =
          currentProgress + progressDelta * progressValuesArray[frameIndex];

        for (let i = 0; i < travelAnimations.length; i++) {
          travelAnimations[i].callback(progress);
        }

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

        requestAnimationFrame(callbackLoop);
      } else {
        const finalProgress = targetProgress;

        for (let i = 0; i < travelAnimations.length; i++) {
          travelAnimations[i].callback(finalProgress);
        }

        Promise.all(stackingAnimationPromises).then(() => {
          callback();
        });
      }
    };

    requestAnimationFrame(callbackLoop);
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
        new Promise((resolve) => animateContent(resolve)),
        new Promise((resolve) => animateTravelCallbacks(resolve)),
      ]).then(() => {
        setSegment([destinationDetent, destinationDetent]);
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
    touchGestureActive,
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
    scrollContainerClientHeight: scrollContainer.clientHeight,
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
      touchGestureActive,
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
