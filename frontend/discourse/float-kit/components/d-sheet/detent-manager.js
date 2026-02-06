/**
 * Manages detent positions and stepping logic for the d-sheet component.
 *
 * Detents are discrete snap positions (e.g., half-height, full-height) that sheets can settle at.
 * This manager handles: calculating which detent to step to based on user interaction,
 * detecting when the sheet is "stuck" at content boundaries, and determining when to auto-step
 * to the next detent. Works closely with the sheet controller to provide smooth, intuitive
 * navigation through detent positions during drag, scroll, and programmatic operations.
 */
export default class DetentManager {
  /**
   * Reference to the parent sheet controller.
   *
   * @type {import("./controller").default}
   */
  controller;

  /**
   * @param {import("./controller").default} controller - The sheet controller instance
   */
  constructor(controller) {
    this.controller = controller;
  }

  /**
   * Get the effective detent configurations with implicit full-height appended.
   * When no detents are configured, returns a single full-height marker.
   *
   * @type {Array<string>}
   */
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

  /**
   * Get the maximum detent index (1-based).
   *
   * @type {number}
   */
  get maxDetent() {
    return this.effectiveDetents?.length ?? 1;
  }

  /**
   * Calculate the next detent index for stepping.
   *
   * @param {string} [direction="up"] - Direction to step ("up" or "down")
   * @param {number|null} [targetDetent=null] - Optional specific detent to step to
   * @returns {number|null} Resolved detent index or null if no step needed
   */
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

  /**
   * Check if a target detent is valid for stepping.
   *
   * @param {number} detent - Target detent index (1-based)
   * @returns {boolean} Whether the detent is valid
   */
  isValidDetent(detent) {
    const detentCount = this.maxDetent;
    return (
      detent >= 1 &&
      detent <= detentCount &&
      detent !== this.controller.activeDetent
    );
  }

  /**
   * Check if stuck position auto-step should trigger.
   *
   * @returns {boolean} Whether auto-step conditions are met
   */
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

  /**
   * Determine stuck position from segment.
   *
   * @param {Array<number>} segment - Current segment [start, end]
   * @param {Array<number>|null} prevSegment - Previous segment
   * @returns {{ backStuck: boolean, frontStuck: boolean, shouldStep: string|null }}
   */
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
