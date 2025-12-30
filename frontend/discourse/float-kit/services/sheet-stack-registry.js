import { guidFor } from "@ember/object/internals";
import Service from "@ember/service";
import { TrackedMap } from "@ember-compat/tracked-built-ins";

/**
 * Service for managing sheet stacks.
 * Tracks which sheets belong to which stacks and maintains the stacking order.
 * Enables stacking-driven animations where sheets that are covered by other
 * sheets can animate based on stacking progress.
 */
export default class SheetStackRegistry extends Service {
  /** @type {TrackedMap<string, Object>} */
  stacks = new TrackedMap();

  /** @type {TrackedMap<string, Object[]>} */
  stackSheets = new TrackedMap();

  /** @type {TrackedMap<string, number>} */
  stackingCounts = new TrackedMap();

  /**
   * Register a new stack.
   *
   * @param {Object} stack - Stack instance with id property
   * @returns {string} The stack ID
   */
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
    return id;
  }

  /**
   * Unregister a stack.
   *
   * @param {string} stackId
   */
  unregisterStack(stackId) {
    this.stacks.delete(stackId);
    this.stackSheets.delete(stackId);
    this.stackingCounts.delete(stackId);
  }

  /**
   * Register a sheet with a stack.
   *
   * @param {string} stackId
   * @param {Object} controller
   */
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

  /**
   * Unregister a sheet from its stack.
   *
   * @param {Object} controller
   */
  unregisterSheetFromStack(controller) {
    const stackId = controller.stackId;
    if (!stackId) {
      return;
    }

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
      const positionState = parentSheet.positionMachine?.current;
      if (positionState?.startsWith("covered-")) {
        parentSheet.sendToPositionMachine("GOTO_FRONT_IDLE");
      }
    }
  }

  /**
   * Update belowSheetsInStack for all sheets in a stack.
   * belowSheetsInStack contains sheets that are visually below the current sheet
   * (sheets with lower stackingIndex that opened before this one).
   *
   * @param {string} stackId
   */
  updateBelowSheetsInStack(stackId) {
    const sheets = this.stackSheets.get(stackId);
    if (!sheets) {
      return;
    }

    sheets.forEach((sheet, index) => {
      sheet.stackingIndex = index;
      const sheetsBelow = sheets.filter((s) => s.stackingIndex < index);
      sheet.belowSheetsInStack = sheetsBelow;
    });

    this.updateSelfAndAboveTravelProgressSumInStack(stackId);
  }

  /**
   * Update selfAndAboveTravelProgressSum for all sheets in a stack.
   *
   * @param {string} stackId
   */
  updateSelfAndAboveTravelProgressSumInStack(stackId) {
    const sheets = this.stackSheets.get(stackId);
    if (!sheets) {
      return;
    }

    const sortedSheets = [...sheets].sort(
      (a, b) => b.stackingIndex - a.stackingIndex
    );

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

  /**
   * Update a sheet's travel progress and recalculate selfAndAboveTravelProgressSum.
   *
   * @param {Object} controller
   * @param {number} progress - Current travel progress (0-1)
   */
  updateSheetTravelProgress(controller, progress) {
    if (!controller || !controller.stackId) {
      return;
    }

    controller.travelProgress = progress;
    this.updateSelfAndAboveTravelProgressSumInStack(controller.stackId);
  }

  /**
   * Get all sheets in a stack.
   *
   * @param {string} stackId
   * @returns {Object[]}
   */
  getSheetsInStack(stackId) {
    return this.stackSheets.get(stackId) || [];
  }

  /**
   * Get the previous (parent) sheet in stack relative to a given sheet.
   *
   * @param {string} stackId
   * @param {Object} controller
   * @returns {Object|null}
   */
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

  /**
   * Get the topmost (front) sheet in stack.
   *
   * @param {string} stackId
   * @returns {Object|null}
   */
  getTopmostSheetInStack(stackId) {
    const sheets = this.stackSheets.get(stackId);
    if (!sheets || sheets.length === 0) {
      return null;
    }
    return sheets[sheets.length - 1];
  }

  /**
   * Check if any sheet in the stack is currently animating (not in idle position).
   *
   * @param {string} stackId
   * @returns {boolean}
   */
  isStackAnimating(stackId) {
    const sheets = this.stackSheets.get(stackId);
    if (!sheets) {
      return false;
    }

    return sheets.some((sheet) => {
      const positionState = sheet.positionMachine?.current;
      return (
        positionState &&
        positionState !== "out" &&
        !positionState.endsWith(".idle")
      );
    });
  }

  /**
   * Notify parent sheet that a new sheet is opening above it.
   *
   * @param {string} stackId
   * @param {Object} newSheetController
   * @param {Object} options
   */
  notifyParentSheetOfChildOpening(stackId, newSheetController, options = {}) {
    const parentSheet = this.getPreviousSheetInStack(
      stackId,
      newSheetController
    );
    if (!parentSheet) {
      return;
    }

    parentSheet.sendToPositionMachine({
      type: "READY_TO_GO_DOWN",
      skipOpening: options.skipOpening || false,
    });
  }

  /**
   * Notify parent sheet that a child sheet is closing.
   *
   * @param {string} stackId
   * @param {Object} closingSheetController
   */
  notifyParentSheetOfChildClosing(stackId, closingSheetController) {
    const parentSheet = this.getPreviousSheetInStack(
      stackId,
      closingSheetController
    );
    if (!parentSheet) {
      return;
    }

    parentSheet.sendToPositionMachine("READY_TO_GO_UP");
  }

  /**
   * Notify parent sheet that a child sheet closed immediately (SWIPE_OUT).
   *
   * @param {string} stackId
   * @param {Object} closingSheetController
   */
  notifyParentSheetOfChildClosingImmediate(stackId, closingSheetController) {
    const parentSheet = this.getPreviousSheetInStack(
      stackId,
      closingSheetController
    );
    if (!parentSheet) {
      return;
    }

    const parentPosition = parentSheet.positionMachine?.current;

    if (
      parentPosition === "covered-going-down" ||
      parentPosition === "covered-going-up"
    ) {
      parentSheet.sendToPositionMachine("GOTO_FRONT_IDLE");
    } else {
      parentSheet.sendToPositionMachine("GO_UP");
    }
  }

  /**
   * Get the stack instance.
   *
   * @param {string} stackId
   * @returns {Object|null}
   */
  getStack(stackId) {
    return this.stacks.get(stackId) || null;
  }

  /**
   * Get the current stacking count.
   *
   * @param {string} stackId
   * @returns {number}
   */
  getStackingCount(stackId) {
    return this.stackingCounts.get(stackId) || 0;
  }

  /**
   * Increment the stacking count. Called when a sheet enters idleInside state.
   *
   * @param {string} stackId
   * @returns {number}
   */
  incrementStackingCount(stackId) {
    const currentCount = this.stackingCounts.get(stackId) || 0;
    const newCount = currentCount + 1;
    this.stackingCounts.set(stackId, newCount);
    return newCount;
  }

  /**
   * Decrement the stacking count. Called when a sheet enters idleOutside state.
   *
   * @param {string} stackId
   * @returns {number}
   */
  decrementStackingCount(stackId) {
    const currentCount = this.stackingCounts.get(stackId) || 0;
    const newCount = Math.max(0, currentCount - 1);
    this.stackingCounts.set(stackId, newCount);
    return newCount;
  }
}
