/**
 * Adapter for coordinating sheet stacking behavior in the d-sheet system.
 * Acts as a bridge between individual sheet controllers and the SheetStackRegistry service,
 * managing stack position tracking, parent-child sheet notifications, and stacking animations.
 * Each sheet controller owns one StackingAdapter instance to participate in stacked sheet navigation.
 * Key responsibilities: stack bookkeeping, parent notifications during open/close, and propagating
 * travel progress to sheets below in the stack for coordinated animation effects.
 */

import { createTweenFunction } from "./animation";

/**
 * Adapter for managing sheet stacking within a registry.
 * Encapsulates stack bookkeeping and parent-child sheet notifications.
 *
 * This adapter delegates to the SheetStackRegistry service for:
 * - Stack position tracking (stackPosition)
 * - Stacking count management (increment/decrement on idle state changes)
 * - Parent sheet notifications (opening, closing, closing immediate)
 * - Travel progress updates
 */
export default class StackingAdapter {
  /** @type {number} */
  stackPosition = 0;

  /**
   * @param {Object} controller - The sheet controller instance that owns this adapter
   */
  constructor(controller) {
    /** @type {Object} */
    this.controller = controller;
  }

  /**
   * Get the stack registry from controller.
   *
   * @returns {Object|null} The SheetStackRegistry service or null if not configured
   */
  get registry() {
    return this.controller.sheetStackRegistry;
  }

  /**
   * Get the stack ID from controller.
   *
   * @returns {string|null} The stack ID this sheet belongs to, or null if not in a stack
   */
  get stackId() {
    return this.controller.stackId;
  }

  /**
   * Whether stacking is enabled (has both stackId and registry).
   *
   * @returns {boolean} True if this sheet is part of a managed stack
   */
  get isStackEnabled() {
    return Boolean(this.stackId && this.registry);
  }

  /**
   * Handle travel status change for stacking bookkeeping.
   * Updates stack position and stacking count based on status transitions.
   *
   * @param {string} status - New travel status ("idleInside"|"idleOutside"|"stepping"|"travellingIn"|"travellingOut")
   * @param {string} previousStatus - Previous travel status for transition detection
   */
  handleTravelStatusChange(status, previousStatus) {
    if (!this.isStackEnabled) {
      return;
    }

    const stackingCount = this.registry.getStackingCount(this.stackId);

    if (previousStatus !== "stepping" && status === "idleInside") {
      if (this.stackPosition === 0) {
        this.stackPosition = stackingCount + 1;
      }
      this.registry.incrementStackingCount(this.stackId);
      this.updateStackingIndexWithPositionValue();
    } else if (status === "idleOutside") {
      this.stackPosition = 0;
      this.registry.decrementStackingCount(this.stackId);
      this.updateStackingIndexWithPositionValue();
    }
  }

  /**
   * Notify parent sheet that this sheet is opening.
   * Triggers parent's position machine to transition to covered state.
   *
   * @param {boolean} [skipOpening=false] - Whether to skip the opening animation
   */
  notifyParentOfOpening(skipOpening = false) {
    if (!this.isStackEnabled) {
      return;
    }

    this.registry.notifyParentSheetOfChildOpening(
      this.stackId,
      this.controller,
      {
        skipOpening,
      }
    );
  }

  /**
   * Notify parent sheet that this sheet is closing with animation.
   * Triggers parent's position machine to prepare for uncovering.
   */
  notifyParentOfClosing() {
    if (!this.isStackEnabled) {
      return;
    }

    this.registry.notifyParentSheetOfChildClosing(
      this.stackId,
      this.controller
    );
  }

  /**
   * Notify parent sheet that this sheet is closing immediately without animation.
   * Triggers parent's position machine to immediately return to front state.
   */
  notifyParentOfClosingImmediate() {
    if (!this.isStackEnabled) {
      return;
    }

    this.registry.notifyParentSheetOfChildClosingImmediate(
      this.stackId,
      this.controller
    );
  }

  /**
   * Update travel progress in the registry.
   * Used to track sheet position for stacking calculations.
   *
   * @param {number} progress - Travel progress value between 0 (outside) and 1 (fully inside)
   */
  updateTravelProgress(progress) {
    if (!this.isStackEnabled) {
      return;
    }

    this.registry.updateSheetTravelProgress(this.controller, progress);
  }

  /**
   * Notify sheets below this one in the stack with stacking progress.
   * Calls each below sheet's aggregatedStackingCallback to animate their covered state.
   *
   * @param {number} progress - Stacking progress value between 0 and 1
   */
  notifyBelowSheets(progress) {
    const belowSheets = this.controller.belowSheetsInStack;
    if (!belowSheets || belowSheets.length === 0) {
      return;
    }

    const belowSheetsLength = belowSheets.length;
    const sumIndex = belowSheetsLength - 1;

    for (const belowSheet of belowSheets) {
      const progressSum =
        belowSheet.selfAndAboveTravelProgressSum?.[sumIndex] ?? 0;
      const accumulatedProgress = progressSum + progress;
      const accumulatedTween = createTweenFunction(accumulatedProgress);

      belowSheet.aggregatedStackingCallback(
        accumulatedProgress,
        accumulatedTween
      );
    }
  }

  /**
   * Get the parent (previous) sheet in the stack.
   * The parent is the sheet that was opened before this one.
   *
   * @returns {Object|null} The parent sheet controller, or null if none exists
   */
  getParentSheet() {
    if (!this.isStackEnabled) {
      return null;
    }

    return this.registry.getPreviousSheetInStack(this.stackId, this.controller);
  }

  /**
   * Notify parent sheet's position machine to advance.
   * Sends "NEXT" message to continue the parent's state machine transitions.
   */
  notifyParentPositionMachineNext() {
    const parentSheet = this.getParentSheet();
    if (parentSheet) {
      parentSheet.sendToPositionMachine("NEXT");
    }
  }

  /**
   * Update this sheet's staging state in the stack registry.
   *
   * @param {string} staging - The staging state ("none", "opening", "closing", etc.)
   */
  updateStagingInStack(staging) {
    if (!this.isStackEnabled) {
      return;
    }

    this.registry.updateSheetStagingInStack(
      this.stackId,
      this.controller.id,
      staging
    );
  }

  /**
   * Remove this sheet's staging data from the stack registry.
   */
  removeStagingFromStack() {
    if (!this.isStackEnabled) {
      return;
    }

    this.registry.removeSheetStagingFromStack(this.stackId, this.controller.id);
  }

  /**
   * Get the merged staging state for the stack.
   *
   * @returns {string} "none" or "not-none"
   */
  getMergedStaging() {
    if (!this.isStackEnabled) {
      return "none";
    }

    return this.registry.getMergedStagingForStack(this.stackId);
  }

  /**
   * Update stacking index with position machine's value.
   */
  updateStackingIndexWithPositionValue() {
    if (!this.isStackEnabled) {
      return;
    }

    const positionValue = this.controller.state?.position?.current ?? "out";
    this.registry.updateSheetStackingIndex(this.controller, positionValue);
  }
}
