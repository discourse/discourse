/**
 * Stacking adapter for d-sheet.
 * Encapsulates sheet stack registry bookkeeping and parent notifications.
 *
 * @class StackingAdapter
 */
export default class StackingAdapter {
  /**
   * @param {Object} controller - The sheet controller instance
   */
  constructor(controller) {
    this.controller = controller;
  }

  /**
   * Get the stack registry from controller.
   *
   * @returns {Object|null}
   */
  get registry() {
    return this.controller.sheetStackRegistry;
  }

  /**
   * Get the stack ID from controller.
   *
   * @returns {string|null}
   */
  get stackId() {
    return this.controller.stackId;
  }

  /**
   * Check if stacking is enabled for this sheet.
   *
   * @returns {boolean}
   */
  get isStackEnabled() {
    return Boolean(this.stackId && this.registry);
  }

  /**
   * Handle travel status change for stacking bookkeeping.
   *
   * @param {string} status - New travel status
   * @param {string} previousStatus - Previous travel status
   */
  handleTravelStatusChange(status, previousStatus) {
    if (!this.isStackEnabled) {
      return;
    }

    const stackingCount = this.registry.getStackingCount(this.stackId);

    if (previousStatus !== "stepping" && status === "idleInside") {
      if (this.controller.myStackPosition === 0) {
        this.controller.myStackPosition = stackingCount + 1;
      }
      this.registry.incrementStackingCount(this.stackId);
    } else if (status === "idleOutside") {
      this.controller.myStackPosition = 0;
      this.registry.decrementStackingCount(this.stackId);
    }

    this.controller.previousTravelStatus = status;
  }

  /**
   * Notify parent sheet that this sheet is opening.
   *
   * @param {boolean} skipOpening - Whether to skip opening animation
   */
  notifyParentOfOpening(skipOpening = false) {
    if (!this.isStackEnabled) {
      return;
    }

    this.registry.notifyParentSheetOfChildOpening(this.stackId, this.controller, {
      skipOpening,
    });
  }

  /**
   * Notify parent sheet that this sheet is closing.
   */
  notifyParentOfClosing() {
    if (!this.isStackEnabled) {
      return;
    }

    this.registry.notifyParentSheetOfChildClosing(this.stackId, this.controller);
  }

  /**
   * Notify parent sheet that this sheet is closing immediately (without animation).
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
   *
   * @param {number} progress - Travel progress value
   */
  updateTravelProgress(progress) {
    if (!this.isStackEnabled) {
      return;
    }

    this.registry.updateSheetTravelProgress(this.controller, progress);
  }

  /**
   * Notify below sheets in stack with stacking callback.
   *
   * @param {number} progress - Progress value
   * @param {Function} tween - Tween function
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
   * Get the parent sheet in the stack.
   *
   * @returns {Object|null}
   */
  getParentSheet() {
    if (!this.isStackEnabled) {
      return null;
    }

    return this.registry.getPreviousSheetInStack(this.stackId, this.controller);
  }

  /**
   * Notify parent sheet's position machine to advance.
   */
  notifyParentPositionMachineNext() {
    const parentSheet = this.getParentSheet();
    if (parentSheet) {
      parentSheet.sendToPositionMachine("NEXT");
    }
  }
}

