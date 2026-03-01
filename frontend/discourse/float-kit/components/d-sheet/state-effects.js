import { EVENTS } from "./state-machine-events";

export function buildStateEffects(controller) {
  return [
    {
      machine: "staging",
      state: "opening",
      timing: "after-paint",
      callback: () => {
        requestAnimationFrame(() => {
          controller.state.openness.readyToOpen(false);
        });
      },
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
      guard: () => {
        const msg = controller.state.openness.lastProcessedMessage;
        return [
          EVENTS.NEXT,
          EVENTS.PREPARED,
          EVENTS.STEP,
          EVENTS.READY_TO_OPEN,
        ].includes(msg?.type);
      },
      callback: (message) => controller.handleOpen(message),
    },
    {
      machine: "openness",
      state: "open.evaluateCloseMessage:true",
      transition: EVENTS.CLOSE,
      callback: () => controller.evaluateCloseMessage(),
    },
    {
      machine: "openness",
      state: "open.evaluateCloseMessage:false",
      transition: EVENTS.CLOSE,
      callback: () => controller.evaluateCloseMessage(),
    },
    { machine: "openness", state: "closing", handler: "handleClosing" },
    {
      machine: "openness",
      state: "closed.status:pending",
      handler: "handleClosedPending",
    },
    {
      machine: "openness",
      state: "closed.status:safe-to-unmount",
      handler: "handleClosedSafeToUnmount",
    },
    {
      machine: "openness",
      state: "closed.status:flushing-to-preparing-opening",
      timing: "before-paint",
      callback: () => {
        controller.timeoutManager.clear("pendingFlush");
        controller.state.flushClosedStatus();
      },
    },
    {
      machine: "openness",
      state: "closed.status:flushing-to-preparing-open",
      timing: "before-paint",
      callback: () => {
        controller.timeoutManager.clear("pendingFlush");
        controller.state.flushClosedStatus();
      },
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
        controller.state.advancePositionAuto();
      },
    },
    {
      machine: "openness",
      state: "open.scroll:ongoing",
      callback: () => {
        const currentProgress =
          controller.dimensions?.progressValueAtDetents?.[
            controller.activeDetent
          ]?.exact ?? 0;
        controller.progressSmoother =
          controller.createProgressSmoother(currentProgress);
      },
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
      state: "ongoing",
      timing: "immediate",
      callback: () => controller.touchHandler.handleScrollStart(),
    },
    {
      machine: "touch",
      state: "ended",
      timing: "immediate",
      callback: () => controller.touchHandler.handleScrollEnd(),
    },
  ];
}
