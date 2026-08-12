import { EVENTS } from "./state-machine-events";

export function buildStateEffects(controller) {
  return [
    {
      machine: "staging",
      state: "opening",
      timing: "immediate",
      handler: "ensurePresented",
    },
    {
      machine: "staging",
      state: "opening",
      timing: "before-paint",
      handler: "handleOpeningTravelStart",
    },
    {
      machine: "staging",
      state: "opening",
      timing: "after-paint",
      callback: () => {
        controller.timeoutManager.scheduleAnimationFrame(
          "stagingOpeningReady",
          () => controller.state.openness.readyToOpen(false)
        );
      },
    },
    {
      machine: "staging",
      state: "open",
      timing: "immediate",
      handler: "handleSkippedOpening",
    },
    {
      machine: "staging",
      state: "open",
      timing: "immediate",
      handler: "ensurePresented",
    },
    {
      machine: "staging",
      state: "open",
      timing: "after-paint",
      callback: () => {
        controller.timeoutManager.scheduleAnimationFrame(
          "stagingOpenReady",
          () => controller.completeSkippedOpening()
        );
      },
    },
    {
      machine: "staging",
      state: "closing",
      timing: "immediate",
      handler: "ensureDismissed",
    },
    {
      machine: "staging",
      state: "closing",
      timing: "after-paint",
      callback: () => {
        controller.handleStateTransition({ type: EVENTS.READY_TO_CLOSE });
      },
    },
    {
      machine: "openness",
      state: "opening",
      timing: "before-paint",
      handler: "handleOpening",
    },
    {
      machine: "elementsReady",
      state: "true",
      timing: "immediate",
      guard: () => controller.state.openness.current === "opening",
      callback: () => controller.startOpeningAnimation(),
    },
    {
      machine: "openness",
      state: "open",
      callback: (message) => {
        if (
          [EVENTS.NEXT, EVENTS.PREPARED, EVENTS.READY_TO_OPEN].includes(
            message?.type
          )
        ) {
          controller.handleOpen(message);
        }
      },
    },
    {
      machine: "openness",
      state: "open",
      timing: "after-paint",
      guard: () => controller.state.staging.isNone,
      callback: () => controller.setupIntersectionObserver(),
    },
    {
      machine: "openness",
      state: "open",
      timing: "before-paint",
      guard: () => controller.state.skip.isOpening,
      callback: () => controller.startSkippedOpeningTravel(),
    },
    {
      machine: "openness",
      state: "open",
      timing: "immediate",
      type: "exit",
      callback: () => {
        controller.cleanupIntersectionObserver();
        controller.timeoutManager.clear("scrollEnd");
        controller.resetWebkitSmallSpacerTransform();
      },
    },
    {
      machine: "openness",
      state: "open",
      timing: "immediate",
      type: "exit",
      callback: () => controller.handleManualTravelEnd(),
    },
    {
      machine: "openness",
      state: "open.swipe:ongoing",
      timing: "immediate",
      callback: () => controller.handleManualTravelStart(),
    },
    {
      machine: "openness",
      state: "open.swipe:ended",
      timing: "immediate",
      callback: () => controller.handleManualTravelEnd(),
    },
    {
      machine: "openness",
      state: "open.evaluateCloseMessage:true",
      transition: EVENTS.CLOSE,
      type: "transition",
      callback: () => controller.evaluateCloseMessage(),
    },
    {
      machine: "openness",
      state: "open.evaluateCloseMessage:false",
      transition: EVENTS.CLOSE,
      type: "transition",
      callback: () => controller.evaluateCloseMessage(),
    },
    {
      machine: "openness",
      state: "open.evaluateStepMessage:true",
      transition: EVENTS.STEP,
      type: "transition",
      callback: (message) => controller.evaluateStepMessage(message),
    },
    {
      machine: "openness",
      state: "open.evaluateStepMessage:false",
      transition: EVENTS.STEP,
      type: "transition",
      callback: (message) => controller.evaluateStepMessage(message),
    },
    { machine: "openness", state: "closing", handler: "handleClosing" },
    {
      machine: "openness",
      state: "closed.status:pending",
      handler: "handleClosedPending",
    },
    {
      machine: "openness",
      state: "closed.status:pending",
      callback: () => controller.state.openness.swipeReset(),
    },
    {
      machine: "openness",
      state: "closed.status:safe-to-unmount",
      handler: "handleClosedSafeToUnmount",
    },
    {
      machine: "longRunning",
      state: "false",
      timing: "before-paint",
      callback: () => controller.removeAllOutletPersistedStyles(),
    },
    {
      machine: "openness",
      state: "closed.status:preparing-opening",
      timing: "after-paint",
      callback: () => {
        controller.state.beginEnterAnimation(false);
      },
    },
    {
      machine: "openness",
      state: "closed.status:preparing-open",
      timing: "after-paint",
      callback: () => {
        controller.state.beginEnterAnimation(true);
      },
    },
    {
      machine: "position",
      state: "covered.status:going-down",
      callback: () => {
        controller.coveredCount++;
        controller.stackingAdapter?.updateStackingIndexWithPositionValue();
        controller.state.staging.goDown();
      },
    },
    {
      machine: "position",
      state: "covered.status:idle",
      callback: () => {
        if (
          controller.state.staging.matches("going-down") ||
          controller.state.staging.matches("go-down")
        ) {
          controller.state.staging.advance();
        }
      },
    },
    {
      machine: "position",
      state: "covered.status:going-up",
      callback: () => controller.state.staging.goUp(),
    },
    {
      machine: "position",
      state: "covered.status:indeterminate",
      callback: () => {
        controller.coveredCount--;
        controller.stackingAdapter?.updateStackingIndexWithPositionValue();

        if (controller.state.staging.matches("going-up")) {
          controller.state.staging.advance();
        }

        if (controller.coveredCount === 0) {
          controller.state.position.goToFrontIdle();
        } else {
          controller.state.position.goToCoveredIdle();
        }
      },
    },
    {
      machine: "position",
      state: "covered.status:come-back",
      timing: "immediate",
      callback: () => {
        controller.state.position.advanceTransient();
      },
    },
    {
      machine: "openness",
      state: "open.scroll:ongoing",
      callback: () => {
        controller.markScrollOccurred();
        const currentProgress =
          controller.lastProcessedProgress ??
          controller.dimensions?.progressValueAtDetents?.[
            controller.currentSegment[1]
          ]?.exact ??
          0;
        controller.progressSmoother =
          controller.createProgressSmoother(currentProgress);
      },
    },
    {
      machine: "openness",
      state: "open.scroll:ended",
      timing: "after-paint",
      callback: () => controller.handleScrollEndedAfterPaint(),
    },
    {
      machine: "staging",
      state: "none",
      timing: "immediate",
      callback: () => controller.stackingAdapter?.updateStagingInStack("none"),
    },
    {
      machine: "staging",
      state: "opening",
      timing: "immediate",
      callback: () =>
        controller.stackingAdapter?.updateStagingInStack("opening"),
    },
    {
      machine: "staging",
      state: "open",
      timing: "immediate",
      callback: () => controller.stackingAdapter?.updateStagingInStack("open"),
    },
    {
      machine: "staging",
      state: "stepping",
      timing: "immediate",
      callback: () =>
        controller.stackingAdapter?.updateStagingInStack("stepping"),
    },
    {
      machine: "staging",
      state: "stepping",
      timing: "after-paint",
      handler: "handleStepMessage",
    },
    {
      machine: "staging",
      state: "closing",
      timing: "immediate",
      callback: () =>
        controller.stackingAdapter?.updateStagingInStack("closing"),
    },
    {
      machine: "staging",
      state: "go-down",
      timing: "immediate",
      callback: () =>
        controller.stackingAdapter?.updateStagingInStack("go-down"),
    },
    {
      machine: "staging",
      state: "going-down",
      timing: "immediate",
      callback: () =>
        controller.stackingAdapter?.updateStagingInStack("going-down"),
    },
    {
      machine: "staging",
      state: "going-up",
      timing: "immediate",
      callback: () =>
        controller.stackingAdapter?.updateStagingInStack("going-up"),
    },
    {
      machine: "touch",
      state: "ended",
      timing: "immediate",
      callback: () => controller.handleTouchEnded(),
    },
  ];
}
