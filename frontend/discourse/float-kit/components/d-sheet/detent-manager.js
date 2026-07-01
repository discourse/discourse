export default class DetentManager {
  controller;

  constructor(controller) {
    this.controller = controller;
  }

  get effectiveDetents() {
    const config = this.controller.detentsConfig;

    if (config === null || config === undefined) {
      return ["var(--d-sheet-content-travel-axis)"];
    }

    if (typeof config === "string") {
      return [config, "var(--d-sheet-content-travel-axis)"];
    }

    return [...config, "var(--d-sheet-content-travel-axis)"];
  }

  get maxDetent() {
    return this.effectiveDetents?.length ?? 1;
  }

  calculateStep(direction = "up", targetDetent = null) {
    const { activeDetent } = this.controller;
    const detentCount = this.maxDetent;

    let resolvedDetent = targetDetent;

    if (resolvedDetent === null) {
      if (direction === "up") {
        resolvedDetent = activeDetent < detentCount ? activeDetent + 1 : 1;
      } else {
        resolvedDetent = activeDetent > 1 ? activeDetent - 1 : detentCount;
      }
    }

    if (resolvedDetent === 0 || resolvedDetent === activeDetent) {
      return null;
    }

    return resolvedDetent;
  }

  isValidDetent(detent) {
    const detentCount = this.maxDetent;
    return (
      detent >= 1 &&
      detent <= detentCount &&
      detent !== this.controller.activeDetent
    );
  }

  shouldAutoStepToStuckPosition() {
    const { controller } = this;
    return (
      controller.edgeAlignedNoOvershoot &&
      controller.snapToEndDetentsAcceleration === "auto" &&
      controller.state.openness.isScrollEnded &&
      !controller.state.openness.isSwipeOngoing &&
      controller.state.openness.isOpen
    );
  }

  determineStuckPosition(segment, prevSegment) {
    const [start, end] = segment;
    const [prevStart, prevEnd] = prevSegment || [];
    const detentCount = this.maxDetent;

    let backStuck = false;
    let frontStuck = false;
    let shouldStep = null;

    if (start !== prevStart || end !== prevEnd) {
      if (this.controller.edgeAlignedNoOvershoot && start === 1 && end === 1) {
        backStuck = true;
        if (this.shouldAutoStepToStuckPosition()) {
          shouldStep = "back";
        }
      } else if (start === detentCount && end === detentCount) {
        frontStuck = true;
        if (this.shouldAutoStepToStuckPosition()) {
          shouldStep = "front";
        }
      }
    }

    return { backStuck, frontStuck, shouldStep };
  }
}
