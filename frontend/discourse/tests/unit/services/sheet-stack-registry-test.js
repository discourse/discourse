import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import StackingAdapter from "discourse/float-kit/components/d-sheet/stacking-adapter";

function createSheet(id, registry) {
  const position = {
    isOut: true,
    matchedState: null,
    matches(state) {
      return state === this.matchedState;
    },
  };
  const controller = {
    belowSheetsInStack: [],
    coveredCount: 0,
    id,
    sheetStackRegistry: registry,
    state: { position, staging: { current: "none" } },
    travelStatus: "idleOutside",
    travelProgress: 0,
    positionMessages: [],
    sendToPositionMachine(message) {
      this.positionMessages.push(message);
    },
  };

  controller.stackingAdapter = new StackingAdapter(controller);

  return controller;
}

function moveInside(controller) {
  controller.state.position.isOut = false;
  controller.stackingAdapter.notifyParentOfOpening();
}

function cover(controller) {
  controller.coveredCount++;
  controller.stackingAdapter.updateStackingIndexWithPositionValue();
}

function uncover(controller) {
  controller.coveredCount--;
  controller.stackingAdapter.updateStackingIndexWithPositionValue();
}

module("Unit | Service | sheet-stack-registry", function (hooks) {
  setupTest(hooks);

  test("preserves an existing stack when it is registered again", function (assert) {
    const registry = this.owner.lookup("service:sheet-stack-registry");
    const stackId = registry.registerStack({ id: "stack" });
    const registeredStack = registry.stacks.get(stackId);
    const sheet = createSheet("sheet", registry);
    let animationCalls = 0;

    registry.registerSheetWithStack(stackId, sheet);
    registry.registerStackingAnimation(stackId, {
      callback() {
        animationCalls++;
      },
    });
    registry.updateSheetStagingInStack(stackId, sheet.id, "opening");

    assert.strictEqual(registry.registerStack({ id: stackId }), stackId);
    assert.strictEqual(
      registry.stacks.get(stackId),
      registeredStack,
      "the existing stack object is retained"
    );
    assert.strictEqual(
      registry.getTopmostSheetInStack(stackId),
      sheet,
      "the registered sheet is retained"
    );
    assert.strictEqual(
      registry.getMergedStagingForStack(stackId),
      "not-none",
      "the sheet staging is retained"
    );

    registeredStack.aggregatedStackingCallback(1, () => {});

    assert.strictEqual(
      animationCalls,
      1,
      "the registered animation remains active"
    );
  });

  test("reparents an active sheet without replacing its controller", function (assert) {
    const registry = this.owner.lookup("service:sheet-stack-registry");
    const sourceStackId = registry.registerStack({ id: "source-stack" });
    const targetStackId = registry.registerStack({ id: "target-stack" });
    const sourceParent = createSheet("source-parent", registry);
    const targetParent = createSheet("target-parent", registry);
    const movingSheet = createSheet("moving-sheet", registry);

    const registerActiveSheet = (stackId, sheet) => {
      registry.registerSheetWithStack(stackId, sheet);
      moveInside(sheet);
      sheet.travelStatus = "idleInside";
      sheet.stackingAdapter.handleTravelStatusChange(sheet.travelStatus);
      registry.updateSheetStagingInStack(
        stackId,
        sheet.id,
        sheet.state.staging.current
      );
    };

    registerActiveSheet(sourceStackId, sourceParent);
    registerActiveSheet(sourceStackId, movingSheet);
    registerActiveSheet(targetStackId, targetParent);

    const sheetId = movingSheet.id;
    sourceParent.positionMessages.length = 0;
    targetParent.positionMessages.length = 0;
    sourceParent.state.position.matchedState = "covered.status:idle";

    assert.true(registry.reparentSheet(targetStackId, movingSheet));
    assert.strictEqual(movingSheet.id, sheetId, "the sheet identity is stable");
    assert.strictEqual(
      movingSheet.stackId,
      targetStackId,
      "the controller points at the target stack"
    );
    assert.deepEqual(
      registry.stackSheets.get(sourceStackId).map(({ id }) => id),
      [sourceParent.id],
      "the source stack releases only the moving sheet"
    );
    assert.deepEqual(
      registry.stackSheets.get(targetStackId).map(({ id }) => id),
      [targetParent.id, movingSheet.id],
      "the target stack receives the same controller in order"
    );
    assert.strictEqual(
      registry.stackingCounts.get(sourceStackId),
      1,
      "the active count leaves the source stack"
    );
    assert.strictEqual(
      registry.stackingCounts.get(targetStackId),
      2,
      "the active count moves to the target stack"
    );
    assert.false(
      registry.stackStagingData.get(sourceStackId).has(sheetId),
      "the source stack releases the staging entry"
    );
    assert.strictEqual(
      registry.stackStagingData.get(targetStackId).get(sheetId),
      "none",
      "the target stack receives the current staging entry"
    );
    assert.strictEqual(
      sourceParent.positionMessages.length,
      1,
      "the source parent is restored once"
    );
    assert.deepEqual(
      targetParent.positionMessages,
      [{ type: "READY_TO_GO_DOWN", skipOpening: true }],
      "the target parent is covered once without replaying entry travel"
    );

    assert.false(
      registry.reparentSheet(targetStackId, movingSheet),
      "repeating the target is a no-op"
    );
    assert.strictEqual(
      registry.stackSheets
        .get(targetStackId)
        .filter((sheet) => sheet === movingSheet).length,
      1,
      "the no-op cannot duplicate the controller"
    );
  });

  test("reparents after the source stack has already unmounted", function (assert) {
    const registry = this.owner.lookup("service:sheet-stack-registry");
    const sourceStackId = registry.registerStack({ id: "removed-stack" });
    const targetStackId = registry.registerStack({ id: "remaining-stack" });
    const movingSheet = createSheet("orphaned-sheet", registry);

    registry.registerSheetWithStack(sourceStackId, movingSheet);
    moveInside(movingSheet);
    movingSheet.travelStatus = "idleInside";
    movingSheet.stackingAdapter.handleTravelStatusChange(
      movingSheet.travelStatus
    );

    assert.strictEqual(
      registry.stackingCounts.get(sourceStackId),
      1,
      "the active sheet is initially counted in its source stack"
    );

    registry.unregisterStack(sourceStackId);

    assert.true(registry.reparentSheet(targetStackId, movingSheet));
    assert.strictEqual(
      registry.getTopmostSheetInStack(targetStackId),
      movingSheet,
      "the target stack receives the same controller"
    );
    assert.strictEqual(
      registry.stackingCounts.get(targetStackId),
      1,
      "the active sheet is counted once in the target stack"
    );
    assert.false(
      registry.stackingCounts.has(sourceStackId),
      "detaching cannot recreate state for the removed stack"
    );
    assert.strictEqual(
      movingSheet.stackId,
      targetStackId,
      "the stale source ID is replaced by the target ID"
    );
    assert.strictEqual(
      movingSheet.stackingIndex,
      0,
      "the active sheet receives its target-stack index"
    );
  });

  test("clears persisted stack outlet styles at lifecycle boundaries", function (assert) {
    const registry = this.owner.lookup("service:sheet-stack-registry");
    const stackId = registry.registerStack({ id: "stack" });
    const target = document.createElement("div");
    let restoreCount = 0;

    target.style.transform = "scale(0.9)";
    target.style.transformOrigin = "0 50%";
    registry.registerStackingAnimation(stackId, {
      target,
      restorePersistedStyles() {
        restoreCount++;
        target.style.transform = "rotate(5deg)";
      },
    });

    registry.incrementStackingCount(stackId);
    registry.decrementStackingCount(stackId);

    assert.strictEqual(
      target.style.transform,
      "rotate(5deg)",
      "the last closing sheet delegates restoration to the animation owner"
    );
    assert.notStrictEqual(
      target.style.transformOrigin,
      "",
      "stack cleanup retains modifier-owned static styles"
    );

    target.style.transform = "scale(0.9)";
    registry.unregisterStack(stackId);

    assert.strictEqual(
      target.style.transform,
      "rotate(5deg)",
      "unregistering the stack delegates restoration to the animation owner"
    );
    assert.strictEqual(
      restoreCount,
      2,
      "each stack lifecycle boundary requests one ownership-aware restoration"
    );
  });

  test("releases stack state when a sheet unmounts while entering", function (assert) {
    const registry = this.owner.lookup("service:sheet-stack-registry");
    const stackId = registry.registerStack({ id: "stack" });
    const sheet = createSheet("sheet", registry);
    const target = document.createElement("div");

    registry.registerSheetWithStack(stackId, sheet);
    registry.registerStackingAnimation(stackId, {
      target,
      restorePersistedStyles() {
        target.style.transform = "rotate(5deg)";
      },
    });

    sheet.stackingAdapter.handleTravelStatusChange("entering", "idleOutside");
    target.style.transform = "scale(0.9)";

    registry.unregisterSheetFromStack(sheet);

    assert.strictEqual(
      target.style.transform,
      "rotate(5deg)",
      "unregistering an active sheet restores the owned stack styles"
    );
  });

  test("preserves stack order through registration, covering, and uncovering", function (assert) {
    const registry = this.owner.lookup("service:sheet-stack-registry");
    const stackId = registry.registerStack({ id: "stack" });
    const bottom = createSheet("bottom", registry);
    const middle = createSheet("middle", registry);
    const top = createSheet("top", registry);

    for (const sheet of [bottom, middle, top]) {
      registry.registerSheetWithStack(stackId, sheet);
      assert.strictEqual(
        sheet.stackingIndex,
        -1,
        `${sheet.id} registers outside the visible stack`
      );
      moveInside(sheet);
    }

    cover(bottom);
    cover(middle);
    cover(bottom);

    assert.deepEqual(
      [bottom.stackingIndex, middle.stackingIndex, top.stackingIndex],
      [2, 1, 0],
      "covering produces a unique depth for every visible sheet"
    );
    assert.deepEqual(
      top.belowSheetsInStack.map(({ id }) => id),
      ["stack", "bottom", "middle"],
      "the top sheet targets every lower stacking layer"
    );

    top.state.position.isOut = true;
    top.stackingAdapter.notifyParentPositionMachineNext();
    uncover(middle);
    uncover(bottom);

    assert.deepEqual(
      [bottom.stackingIndex, middle.stackingIndex, top.stackingIndex],
      [1, 0, -1],
      "the exiting sheet returns to the outside index before unmount"
    );

    registry.unregisterSheetFromStack(top);

    assert.deepEqual(
      middle.belowSheetsInStack.map(({ id }) => id),
      ["stack", "bottom"],
      "unmounting the exited sheet preserves the remaining stack order"
    );
  });

  test("builds cumulative travel progress for each stack layer", function (assert) {
    const registry = this.owner.lookup("service:sheet-stack-registry");
    const stackId = registry.registerStack({ id: "stack" });
    const bottom = createSheet("bottom", registry);
    const middle = createSheet("middle", registry);
    const top = createSheet("top", registry);

    for (const sheet of [bottom, middle, top]) {
      registry.registerSheetWithStack(stackId, sheet);
      moveInside(sheet);
    }

    cover(bottom);
    cover(middle);
    cover(bottom);

    bottom.travelProgress = 1;
    middle.travelProgress = 2;
    top.travelProgress = 3;
    registry.updateSelfAndAboveTravelProgressSumInStack(stackId);

    const stack = registry.stacks.get(stackId);

    assert.deepEqual(
      stack.selfAndAboveTravelProgressSum,
      [0, 1, 3, 6],
      "the base stack accumulates every sheet above it"
    );
    assert.deepEqual(
      bottom.selfAndAboveTravelProgressSum,
      [0, 0, 2, 5],
      "a sheet only accumulates the sheets above its own layer"
    );
    assert.deepEqual(
      middle.selfAndAboveTravelProgressSum,
      [0, 0, 0, 3],
      "the middle sheet accumulates the top sheet"
    );
    assert.deepEqual(
      top.selfAndAboveTravelProgressSum,
      [0, 0, 0, 0],
      "the top sheet has no progress above it"
    );
  });
});
