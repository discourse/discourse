import {
  createTweenFunction,
  generateAnimationConfig,
  supportsLinearEasing,
} from "./animation";
import { toKebabCase } from "./css-utils";
import {
  createOutletAnimationKeyframe,
  normalizeOutletAnimationConfig,
} from "./outlet-animation-config";

const NEVER_CANCELLED = () => false;

export function createTravelEasing(
  progressValues,
  linearEasingSupported = supportsLinearEasing()
) {
  return linearEasingSupported && progressValues.length > 1
    ? `linear(${progressValues.join(",")})`
    : "linear";
}

function setScrollPosition(scrollContainer, scrollAxis, position) {
  if (scrollAxis === "x") {
    scrollContainer.scrollTo(position, 0);
    scrollContainer.scrollLeft = position;
  } else {
    scrollContainer.scrollTo(0, position);
    scrollContainer.scrollTop = position;
  }
}

function revealView(view) {
  const tokens = view?.dataset?.dSheet?.split(/\s+/).filter(Boolean);

  if (!tokens?.includes("hidden")) {
    return;
  }

  view.dataset.dSheet = tokens.filter((token) => token !== "hidden").join(" ");
}

export function resolveTravelTrack(trackToTravelOn, tracks) {
  if (trackToTravelOn) {
    return trackToTravelOn;
  }

  if (tracks === "vertical") {
    return "bottom";
  }

  if (tracks === "horizontal") {
    return "right";
  }

  return tracks;
}

function runFinalTravelCallbacks({
  progress,
  range,
  progressAtDetents,
  travelAnimations,
  belowSheetsInStack,
  onTravel,
  isTravelCancelled,
}) {
  onTravel?.({ progress, range, progressAtDetents });

  if (isTravelCancelled()) {
    return false;
  }

  const tween = createTweenFunction(progress);

  for (const animation of travelAnimations) {
    animation.callback?.(progress, tween);
    if (isTravelCancelled()) {
      return false;
    }
  }

  const sumIndex = belowSheetsInStack.length - 1;
  for (const sheet of belowSheetsInStack) {
    const accumulatedProgress =
      (sheet.selfAndAboveTravelProgressSum?.[sumIndex] ?? 0) + progress;

    sheet.aggregatedStackingCallback?.(
      accumulatedProgress,
      createTweenFunction(accumulatedProgress)
    );
    if (isTravelCancelled()) {
      return false;
    }
  }

  return true;
}

function buildKeyframesFromTemplates(
  templates,
  progressValues,
  supportsLinear,
  stackingInfo = null
) {
  if (!progressValues || progressValues.length === 0) {
    return [];
  }
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
      createOutletAnimationKeyframe(
        templates,
        adjustProgress(progressValues[0])
      ),
      createOutletAnimationKeyframe(
        templates,
        adjustProgress(progressValues[progressValues.length - 1])
      ),
    ];
  }
  return progressValues.map((progress) =>
    createOutletAnimationKeyframe(templates, adjustProgress(progress))
  );
}

function getTransformOrigin(config) {
  const properties =
    config && Object.hasOwn(config, "properties") ? config.properties : config;
  const transformOrigin = properties?.transformOrigin;
  return typeof transformOrigin === "string" ? transformOrigin : undefined;
}
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
    const cleanup = () => {
      animation.removeEventListener("finish", onEnd);
      animation.removeEventListener("cancel", onEnd);
    };
    const onEnd = () => {
      const finalKeyframe = keyframes[keyframes.length - 1];
      if (finalKeyframe && animation.playState === "finished") {
        Object.entries(finalKeyframe).forEach(([property, value]) => {
          target.style.setProperty(toKebabCase(property), value);
        });
      }
      cleanup();
      resolve();
    };

    animation.addEventListener("finish", onEnd);
    animation.addEventListener("cancel", onEnd);
  });
}
export function resolveDestinationDetent(desiredDetent, activeDetent) {
  return typeof desiredDetent === "number" ? desiredDetent : activeDetent;
}
export function calculateScrollPositionForDetent(config) {
  const {
    trackToTravelOn,
    destinationDetent,
    detentCount,
    swipeOutDisabledWithDetent,
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
    } else if (
      (swipeOutDisabledWithDetent && isFirstDetent) ||
      isClosedDetent
    ) {
      scrollPosition = 0;
    } else if (
      !isLastDetent &&
      !(swipeOutDisabledWithDetent && isFirstDetent) &&
      !isClosedDetent
    ) {
      if (swipeOutDisabledWithDetent) {
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
      swipeOutDisabledWithDetent && isFirstDetent
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
    onProgrammaticScroll,
    runOnTravelStart,
    dimensions,
    trackToTravelOn,
    isTravelCancelled = NEVER_CANCELLED,
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

  if (isTravelCancelled()) {
    return;
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

  if (progressValuesArray.length === 0) {
    revealView(view);
    onProgrammaticScroll?.();
    setScrollPosition(scrollContainer, scrollAxis, positionToScrollTo);
    setSegment([destinationDetent, destinationDetent]);
    if (onTravelEnd) {
      onTravelEnd();
    }
    return;
  }

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

  const needsTransform = shouldAnimateContent && transformDistance !== 0;

  const useLinearEasing = supportsLinearEasing();
  const easingValue = createTravelEasing(
    filteredProgressValues,
    useLinearEasing
  );

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
    onProgrammaticScroll?.();
    setScrollPosition(scrollContainer, scrollAxis, finalScrollPosition);
  };
  const animateContent = () => {
    if (!needsTransform || !contentWrapper) {
      return Promise.resolve();
    }

    return new Promise((resolve) => {
      const contentAnimation = contentWrapper.animate(transformKeyframes, {
        duration,
        easing: easingValue,
        delay,
      });
      const cleanup = () => {
        contentAnimation.removeEventListener("finish", onEnd);
        contentAnimation.removeEventListener("cancel", onEnd);
      };
      const onEnd = () => {
        cleanup();
        resolve();
      };

      contentAnimation.addEventListener("finish", onEnd);
      contentAnimation.addEventListener("cancel", onEnd);
    });
  };
  const animateTravelCallbacks = () => {
    const animationOptions = { duration, easing: easingValue, delay };
    const progressValues = useLinearEasing
      ? [
          mappedProgressValues[0],
          mappedProgressValues[mappedProgressValues.length - 1],
        ]
      : mappedProgressValues;

    const allAnimationPromises = [];

    const allAnimations = [
      ...travelAnimations.map((anim) => ({ ...anim, isStacking: false })),
      ...stackingAnimations.map((anim) => ({ ...anim, isStacking: true })),
    ];

    allAnimations
      .filter((anim) => anim.config && anim.target)
      .forEach((anim) => {
        const templates =
          anim.templates ??
          normalizeOutletAnimationConfig(anim.config).templates;
        const stackingInfo = anim.isStacking
          ? {
              reversedStackingIndex: anim.reversedStackingIndex,
              selfAndAboveTravelProgressSum: anim.selfAndAboveTravelProgressSum,
            }
          : null;

        const keyframes = buildKeyframesFromTemplates(
          templates,
          progressValues,
          useLinearEasing,
          stackingInfo
        );

        allAnimationPromises.push(
          animateTarget({
            target: anim.target,
            keyframes,
            animationOptions,
            transformOrigin: getTransformOrigin(anim.config),
          })
        );
      });

    return new Promise((resolve) => {
      let startTime = null;
      const progressReportLoop = (timestamp) => {
        if (isTravelCancelled()) {
          resolve();
          return;
        }

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

          for (let i = 0; i < travelAnimations.length; i++) {
            const anim = travelAnimations[i];
            if (anim.callback && !anim.config) {
              anim.callback(progress);
              if (isTravelCancelled()) {
                resolve();
                return;
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

          if (isTravelCancelled()) {
            resolve();
          } else {
            requestAnimationFrame(progressReportLoop);
          }
        } else {
          const lastDetent = Math.min(
            (dimensions?.progressValueAtDetents?.length ?? 1) - 1,
            destinationDetent
          );
          setSegment([lastDetent, lastDetent]);

          Promise.all(allAnimationPromises).then(resolve);
        }
      };

      requestAnimationFrame(progressReportLoop);
    });
  };

  requestAnimationFrame(() => {
    if (isTravelCancelled()) {
      return;
    }

    requestAnimationFrame(() => {
      if (isTravelCancelled()) {
        return;
      }

      revealView(view);
      setScroll();

      Promise.all([animateContent(), animateTravelCallbacks()]).then(() => {
        if (!isTravelCancelled() && onTravelEnd) {
          onTravelEnd();
        }
      });
    });
  });
}
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
    onTravel,
    onTravelStart,
    onTravelEnd,
    onProgrammaticScroll,
    snapBackAcceleratorTravelAxisSize,
    swipeOutDisabledWithDetent,
    setSegment,
    contentPlacement,
    hasOppositeTracks,
    isTravelCancelled = NEVER_CANCELLED,
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

  const trackToTravelOnResolved = resolveTravelTrack(trackToTravelOn, tracks);

  const scrollInfo = calculateScrollPositionForDetent({
    destinationDetent: resolvedDestination,
    detentCount: dimensions.detentMarkers.length,
    trackToTravelOn: trackToTravelOnResolved,
    swipeOutDisabledWithDetent,
    hasOppositeTracks,
    contentPlacement,
    snapBackAcceleratorSize: snapBackAcceleratorTravelAxisSize,
    elementsDimensions: dimensions,
  });

  const { positionToScrollTo, scrollAxis } = scrollInfo;

  if (positionToScrollTo === null || scrollAxis === null) {
    return;
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
      onProgrammaticScroll,
      runOnTravelStart,
      dimensions,
      trackToTravelOn: trackToTravelOnResolved,
      isTravelCancelled,
    });
  } else {
    if (runTravelCallbacksAndAnimations && runOnTravelStart && onTravelStart) {
      onTravelStart();
    }

    if (isTravelCancelled()) {
      return;
    }

    revealView(view);
    onProgrammaticScroll?.();
    setScrollPosition(scrollContainer, scrollAxis, positionToScrollTo);

    setSegment([resolvedDestination, resolvedDestination]);

    if (runTravelCallbacksAndAnimations) {
      const progress =
        dimensions.progressValueAtDetents[resolvedDestination].exact;
      const range = {
        start: resolvedDestination,
        end: resolvedDestination,
      };

      const travelCompleted = runFinalTravelCallbacks({
        progress,
        range,
        progressAtDetents: dimensions.exactProgressValueAtDetents,
        travelAnimations,
        belowSheetsInStack,
        onTravel,
        isTravelCancelled,
      });
      if (travelCompleted) {
        onTravelEnd?.();
      }
    }
  }
}
