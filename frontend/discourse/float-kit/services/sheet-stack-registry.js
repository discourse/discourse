import { guidFor } from "@ember/object/internals";
import { trackedMap } from "@ember/reactive/collections";
import Service from "@ember/service";
import { EVENTS } from "discourse/float-kit/components/d-sheet/state-machine-events";

export default class SheetStackRegistry extends Service {
  stacks = trackedMap();
  stackSheets = trackedMap();
  stackingCounts = trackedMap();
  stackStagingData = trackedMap();

  registerStack(stack) {
    const id = stack.id || guidFor(stack);

    const stackObject = {
      ...stack,
      id,
      stackingAnimations: [],
      aggregatedStackingCallback(progress, tween) {
        for (let i = 0; i < this.stackingAnimations.length; i++) {
          this.stackingAnimations[i].callback(progress, tween);
        }
      },
      travelProgress: 0,
      selfAndAboveTravelProgressSum: [],
    };

    this.stacks.set(id, stackObject);
    this.stackSheets.set(id, []);
    this.stackStagingData.set(id, new Map());
    return id;
  }

  unregisterStack(stackId) {
    this.removeAllOutletPersistedStyles(stackId);
    this.stacks.delete(stackId);
    this.stackSheets.delete(stackId);
    this.stackingCounts.delete(stackId);
    this.stackStagingData.delete(stackId);
  }

  registerStackingAnimation(stackId, animation) {
    const stack = this.stacks.get(stackId);

    if (!stack) {
      return () => {};
    }

    stack.stackingAnimations.push(animation);

    return () => {
      const index = stack.stackingAnimations.indexOf(animation);
      if (index !== -1) {
        stack.stackingAnimations.splice(index, 1);
      }
    };
  }

  removeAllOutletPersistedStyles(stackId) {
    const stack = this.stacks.get(stackId);

    for (const animation of stack?.stackingAnimations ?? []) {
      for (const property of animation.animatedProperties ?? []) {
        animation.target?.style.removeProperty(property);
      }
    }
  }

  registerSheetWithStack(stackId, controller) {
    const sheets = this.stackSheets.get(stackId);
    if (!sheets) {
      // eslint-disable-next-line no-console
      console.warn(
        `[SheetStackRegistry] Stack ${stackId} not found when registering sheet`
      );
      return;
    }

    sheets.push(controller);
    controller.stackId = stackId;
    controller.stackingIndex = -1;

    this.updateBelowSheetsInStack(stackId);
  }

  unregisterSheetFromStack(controller) {
    const stackId = controller.stackId;
    if (!stackId) {
      return;
    }

    this.removeSheetStagingFromStack(stackId, controller.id);

    const sheets = this.stackSheets.get(stackId);
    if (!sheets) {
      return;
    }

    const index = sheets.indexOf(controller);
    const parentSheet = index > 0 ? sheets[index - 1] : null;

    if (index !== -1) {
      sheets.splice(index, 1);
    }

    controller.stackId = null;
    controller.stackingIndex = -1;
    controller.belowSheetsInStack = [];

    this.updateBelowSheetsInStack(stackId);

    if (parentSheet) {
      const positionState = parentSheet.state?.position;

      if (
        positionState?.matches("covered.status:going-down") ||
        positionState?.matches("covered.status:going-up")
      ) {
        parentSheet.sendToPositionMachine(EVENTS.NEXT);
        parentSheet.sendToPositionMachine(EVENTS.GOTO_FRONT);
      } else if (
        positionState?.matches("covered.status:idle") ||
        positionState?.matches("covered.status:indeterminate")
      ) {
        parentSheet.sendToPositionMachine(EVENTS.GOTO_FRONT);
      }
    }
  }

  updateBelowSheetsInStack(stackId) {
    const sheets = this.stackSheets.get(stackId);
    if (!sheets) {
      return;
    }

    const stack = this.stacks.get(stackId);
    const sheetsCount = sheets.length;

    sheets.forEach((sheet) => {
      const sheetsBelow = sheets.filter(
        (s) => s.stackingIndex > sheet.stackingIndex
      );

      if (stack) {
        sheetsBelow.unshift(stack);
        stack.stackingIndex = sheetsCount - 1;
      }

      sheet.belowSheetsInStack = sheetsBelow;
    });

    this.updateSelfAndAboveTravelProgressSumInStack(stackId);
  }

  updateSelfAndAboveTravelProgressSumInStack(stackId) {
    const sheets = this.stackSheets.get(stackId);
    if (!sheets) {
      return;
    }

    const sortedSheets = [...sheets].sort(
      (a, b) => b.stackingIndex - a.stackingIndex
    );

    const stack = this.stacks.get(stackId);
    if (stack) {
      sortedSheets.unshift(stack);
    }

    const totalCount = sortedSheets.length;

    for (let sheetIndex = 0; sheetIndex < totalCount; sheetIndex++) {
      const sheet = sortedSheets[sheetIndex];
      const progressSums = new Array(totalCount).fill(0);
      let cumulativeProgress = 0;

      for (
        let aboveIndex = sheetIndex + 1;
        aboveIndex < totalCount;
        aboveIndex++
      ) {
        cumulativeProgress += sortedSheets[aboveIndex].travelProgress || 0;
        progressSums[aboveIndex] = cumulativeProgress;
      }

      sheet.selfAndAboveTravelProgressSum = progressSums;
    }
  }

  updateSheetTravelProgress(controller, progress) {
    if (!controller || !controller.stackId) {
      return;
    }

    controller.travelProgress = progress;
    this.updateSelfAndAboveTravelProgressSumInStack(controller.stackId);
  }

  getPreviousSheetInStack(stackId, controller) {
    const sheets = this.stackSheets.get(stackId);
    if (!sheets || sheets.length < 2) {
      return null;
    }

    const index = sheets.indexOf(controller);
    if (index <= 0) {
      return null;
    }

    return sheets[index - 1];
  }

  getTopmostSheetInStack(stackId) {
    const sheets = this.stackSheets.get(stackId);
    if (!sheets || sheets.length === 0) {
      return null;
    }
    return sheets[sheets.length - 1];
  }

  notifyParentSheetOfChildOpening(stackId, newSheetController, options = {}) {
    const parentSheet = this.getPreviousSheetInStack(
      stackId,
      newSheetController
    );
    if (!parentSheet) {
      return;
    }

    parentSheet.sendToPositionMachine({
      type: EVENTS.READY_TO_GO_DOWN,
      skipOpening: options.skipOpening || false,
    });
  }

  notifyParentSheetOfChildClosing(stackId, closingSheetController) {
    const parentSheet = this.getPreviousSheetInStack(
      stackId,
      closingSheetController
    );
    if (!parentSheet) {
      return;
    }

    parentSheet.sendToPositionMachine(EVENTS.READY_TO_GO_UP);
  }

  notifyParentSheetOfChildClosingImmediate(stackId, closingSheetController) {
    const parentSheet = this.getPreviousSheetInStack(
      stackId,
      closingSheetController
    );
    if (!parentSheet) {
      return;
    }

    const positionState = parentSheet.state?.position;

    if (
      positionState?.matches("covered.status:going-down") ||
      positionState?.matches("covered.status:going-up")
    ) {
      parentSheet.sendToPositionMachine(EVENTS.NEXT);
      parentSheet.sendToPositionMachine(EVENTS.GOTO_FRONT);
    } else if (positionState?.matches("covered.status:idle")) {
      parentSheet.sendToPositionMachine(EVENTS.GO_UP);
    } else if (positionState?.matches("covered.status:indeterminate")) {
      parentSheet.sendToPositionMachine(EVENTS.GOTO_FRONT);
    }
  }

  getStackingCount(stackId) {
    return this.stackingCounts.get(stackId) || 0;
  }

  incrementStackingCount(stackId) {
    const currentCount = this.stackingCounts.get(stackId) || 0;
    const newCount = currentCount + 1;
    this.stackingCounts.set(stackId, newCount);
    return newCount;
  }

  decrementStackingCount(stackId) {
    const currentCount = this.stackingCounts.get(stackId) || 0;
    const newCount = Math.max(0, currentCount - 1);
    this.stackingCounts.set(stackId, newCount);
    if (newCount === 0) {
      this.removeAllOutletPersistedStyles(stackId);
    }
    return newCount;
  }

  updateSheetStagingInStack(stackId, sheetId, staging) {
    const stagingData = this.stackStagingData.get(stackId);
    if (!stagingData) {
      return;
    }

    stagingData.set(sheetId, staging);
    this.stackStagingData.set(stackId, new Map(stagingData));
  }

  removeSheetStagingFromStack(stackId, sheetId) {
    const stagingData = this.stackStagingData.get(stackId);
    if (!stagingData) {
      return;
    }

    stagingData.delete(sheetId);
    this.stackStagingData.set(stackId, new Map(stagingData));
  }

  getMergedStagingForStack(stackId) {
    const stagingData = this.stackStagingData.get(stackId);
    if (!stagingData || stagingData.size === 0) {
      return "none";
    }

    for (const staging of stagingData.values()) {
      if (staging !== "none") {
        return "not-none";
      }
    }

    return "none";
  }

  updateSheetStackingIndex(controller, stackingIndex) {
    if (!controller || !controller.stackId) {
      return;
    }

    controller.stackingIndex = stackingIndex;
    this.updateBelowSheetsInStack(controller.stackId);
  }
}
