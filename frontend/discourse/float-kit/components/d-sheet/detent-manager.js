/**
 * Manages detent-related calculations and state for d-sheet.
 * Handles detent navigation and stuck position detection.
 *
 * @class DetentManager
 */
export default class DetentManager {
  /**
   * @param {Object} controller - The sheet controller instance
   */
  constructor(controller) {
    this.c = controller;
  }

  /**
   * Get the effective detent configurations with implicit full-height appended.
   * When no detents are configured, returns a single full-height marker.
   *
   * @type {Array<string>}
   */
  get effectiveDetents() {
    const config = this.c.detentsConfig;
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
   * Calculate the next detent index (for stepping up).
   * Cycles back to first detent when at the last.
   *
   * @returns {number|null} Next detent index or null if no step needed
   */
  calculateNextDetent() {
    const { activeDetent } = this.c;
    const max = this.maxDetent;

    if (max <= 1) {
      return null;
    }

    const nextDetent = activeDetent >= max ? 1 : activeDetent + 1;
    return nextDetent === activeDetent ? null : nextDetent;
  }

  /**
   * Calculate the previous detent index (for stepping down).
   * Cycles to last detent when at the first.
   *
   * @returns {number|null} Previous detent index or null if no step needed
   */
  calculatePrevDetent() {
    const { activeDetent } = this.c;
    const max = this.maxDetent;

    if (max <= 1) {
      return null;
    }

    const prevDetent = activeDetent <= 1 ? max : activeDetent - 1;
    return prevDetent === activeDetent ? null : prevDetent;
  }

  /**
   * Check if a target detent is valid for stepping.
   *
   * @param {number} detent - Target detent index (1-based)
   * @returns {boolean} Whether the detent is valid
   */
  isValidDetent(detent) {
    const max = this.maxDetent;
    return detent >= 1 && detent <= max && detent !== this.c.activeDetent;
  }

  /**
   * Check if stuck position auto-step should trigger.
   *
   * @returns {boolean}
   */
  shouldAutoStepToStuckPosition() {
    const c = this.c;
    return (
      c.edgeAlignedNoOvershoot &&
      c.snapToEndDetentsAcceleration === "auto" &&
      c.stateHelper.isScrollEnded() &&
      !c.stateHelper.isSwipeOngoing() &&
      c.currentState === "open"
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
    const c = this.c;
    const [start, end] = segment;
    const prevStart = prevSegment?.[0];
    const prevEnd = prevSegment?.[1];
    const lastDetent = c.dimensions?.detentMarkers?.length ?? 1;

    let backStuck = false;
    let frontStuck = false;
    let shouldStep = null;

    if (start !== prevStart || end !== prevEnd) {
      if (start === 1 && end === 1) {
        backStuck = true;
        if (this.shouldAutoStepToStuckPosition()) {
          shouldStep = "back";
        }
      } else if (start === lastDetent && end === lastDetent) {
        frontStuck = true;
        if (this.shouldAutoStepToStuckPosition()) {
          shouldStep = "front";
        }
      }
    }

    return { backStuck, frontStuck, shouldStep };
  }
}
