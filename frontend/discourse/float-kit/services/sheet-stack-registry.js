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
    this.stacks.delete(stackId);
    this.stackSheets.delete(stackId);
    this.stackingCounts.delete(stackId);
    this.stackStagingData.delete(stackId);
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
    controller.stackingIndex = sheets.length - 1;

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

    sheets.forEach((sheet, index) => {
      sheet.stackingIndex = sheetsCount - 1 - index;

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

    for (let r = 0; r < totalCount; r++) {
      const sheet = sortedSheets[r];
      sheet.selfAndAboveTravelProgressSum = [];

      for (let o = 0; o < totalCount; o++) {
        if (o <= r) {
          sheet.selfAndAboveTravelProgressSum[o] = 0;
        } else {
          sheet.selfAndAboveTravelProgressSum[o] = sortedSheets
            .slice(r + 1, o + 1)
            .reduce((sum, s) => sum + (s.travelProgress || 0), 0);
        }
      }
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

  updateSheetStackingIndex(controller, positionValue) {
    if (!controller || !controller.stackId) {
      return;
    }

    controller.positionValueForStacking = positionValue;
    this.updateSelfAndAboveTravelProgressSumInStack(controller.stackId);
  }
}
