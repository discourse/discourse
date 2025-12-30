/**
 * Adapter for managing sheet stacking within a registry.
 * Encapsulates stack bookkeeping and parent-child sheet notifications.
 *
 * This adapter delegates to the SheetStackRegistry service for:
 * - Stack position tracking (stackPosition)
 * - Stacking count management (increment/decrement on idle state changes)
 * - Parent sheet notifications (opening, closing, closing immediate)
 * - Travel progress updates
 *
 * @class StackingAdapter
 */
export default class StackingAdapter {
  /**
   * @param {Object} controller - The sheet controller instance that owns this adapter
   */
  constructor(controller) {
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
   * Follows silk implementation behavior:
   * - On transition to "idleInside" (not from "stepping"): set position if unset, increment count
   * - On transition to "idleOutside": reset position to 0, decrement count
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
      if (this.controller.stackPosition === 0) {
        this.controller.stackPosition = stackingCount + 1;
      }
      this.registry.incrementStackingCount(this.stackId);
    } else if (status === "idleOutside") {
      this.controller.stackPosition = 0;
      this.registry.decrementStackingCount(this.stackId);
    }

    this.controller.previousTravelStatus = status;
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
   * This method accesses belowSheetsInStack directly from the controller
   * and does not require isStackEnabled check since it operates on
   * cached sheet references.
   *
   * @param {number} progress - Stacking progress value between 0 and 1
   * @param {Function} tween - Tween function for value interpolation
   */
  notifyBelowSheets(progress, tween) {
    const belowSheets = this.controller.belowSheetsInStack;
    if (belowSheets) {
      for (const belowSheet of belowSheets) {
        belowSheet.aggregatedStackingCallback(progress, tween);
      }
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
}
