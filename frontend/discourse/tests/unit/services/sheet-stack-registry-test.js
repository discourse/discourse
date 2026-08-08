import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import StackingAdapter from "discourse/float-kit/components/d-sheet/stacking-adapter";

function createSheet(id, registry) {
  const position = {
    isOut: true,
    matches() {
      return false;
    },
  };
  const controller = {
    belowSheetsInStack: [],
    coveredCount: 0,
    id,
    sheetStackRegistry: registry,
    state: { position },
    travelProgress: 0,
    sendToPositionMachine() {},
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

  test("clears persisted stack outlet styles at lifecycle boundaries", function (assert) {
    const registry = this.owner.lookup("service:sheet-stack-registry");
    const stackId = registry.registerStack({ id: "stack" });
    const target = document.createElement("div");

    target.style.transform = "scale(0.9)";
    target.style.transformOrigin = "0 50%";
    registry.registerStackingAnimation(stackId, {
      animatedProperties: new Set(["transform"]),
      target,
    });

    registry.incrementStackingCount(stackId);
    registry.decrementStackingCount(stackId);

    assert.strictEqual(
      target.style.transform,
      "",
      "the last closing sheet removes the persisted animation value"
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
      "",
      "unregistering the stack provides the cleanup fallback"
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
