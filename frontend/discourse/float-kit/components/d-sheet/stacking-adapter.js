import { createTweenFunction } from "./animation";
import { EVENTS } from "./state-machine-events";

export default class StackingAdapter {
  stackPosition = 0;

  constructor(controller) {
    this.controller = controller;
  }

  get registry() {
    return this.controller.sheetStackRegistry;
  }

  get stackId() {
    return this.controller.stackId;
  }

  get isStackEnabled() {
    return Boolean(this.stackId && this.registry);
  }

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
    this.updateStackingIndexWithPositionValue();
  }

  notifyParentOfClosing() {
    if (!this.isStackEnabled) {
      return;
    }

    this.registry.notifyParentSheetOfChildClosing(
      this.stackId,
      this.controller
    );
  }

  notifyParentOfClosingImmediate() {
    if (!this.isStackEnabled) {
      return;
    }

    this.registry.notifyParentSheetOfChildClosingImmediate(
      this.stackId,
      this.controller
    );
    this.updateStackingIndexWithPositionValue();
  }

  updateTravelProgress(progress) {
    if (!this.isStackEnabled) {
      return;
    }

    this.registry.updateSheetTravelProgress(this.controller, progress);
  }

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

  getParentSheet() {
    if (!this.isStackEnabled) {
      return null;
    }

    return this.registry.getPreviousSheetInStack(this.stackId, this.controller);
  }

  notifyParentPositionMachineNext() {
    const parentSheet = this.getParentSheet();
    if (parentSheet) {
      parentSheet.sendToPositionMachine(EVENTS.NEXT);
    }
    this.updateStackingIndexWithPositionValue();
  }

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

  removeStagingFromStack() {
    if (!this.isStackEnabled) {
      return;
    }

    this.registry.removeSheetStagingFromStack(this.stackId, this.controller.id);
  }

  getMergedStaging() {
    if (!this.isStackEnabled) {
      return "none";
    }

    return this.registry.getMergedStagingForStack(this.stackId);
  }

  updateStackingIndexWithPositionValue() {
    if (!this.isStackEnabled) {
      return;
    }

    const outOffset = this.controller.state?.position?.isOut ? 1 : 0;

    this.registry.updateSheetStackingIndex(
      this.controller,
      this.controller.coveredCount - outOffset
    );
  }
}
