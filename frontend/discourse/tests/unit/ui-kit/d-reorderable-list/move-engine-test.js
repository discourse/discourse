import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import MoveEngine from "discourse/ui-kit/d-reorderable-list/-internals/engine/move-engine";

/**
 * The engine drives the frozen-row interleaving, which the component tests
 * reach only through rendered output. Exercised directly here because it is
 * the part of the split most able to drift while every rendered assertion
 * still passes: a projection that mislays one frozen row still renders a list
 * of the right length, in an order no assertion names.
 */
module("Unit | ui-kit | DReorderableList | MoveEngine", function (hooks) {
  setupTest(hooks);

  /** Builds the row projection the component would hand the engine. */
  function rowsFor(spec) {
    return spec.map((entry, index) => ({
      item: entry.id,
      key: entry.id,
      index,
      movable: entry.movable !== false,
      isFirst: false,
      isLast: false,
      label: entry.id,
    }));
  }

  function engineFor(spec, overrides = {}) {
    const rows = rowsFor(spec);
    const moves = [];
    const engine = new MoveEngine({
      args: () => ({
        items: rows.map((row) => row.item),
        onMove: (move) => moves.push(move),
        ...overrides,
      }),
      rows: () => rows,
      listId: () => "default",
      announcer: {
        announceMove() {},
        announceBoundary() {},
        noteRun() {},
        updateRun() {},
        cancelRun() {},
      },
      refocusIndex() {},
    });
    return { engine, rows, moves };
  }

  test("a move reorders only the movable subsequence", async function (assert) {
    const { engine, moves } = engineFor([
      { id: "a" },
      { id: "b" },
      { id: "c" },
    ]);

    engine.move("a", "down", "menu");

    assert.deepEqual(moves.at(-1).proposedToItems, ["b", "a", "c"]);
    assert.strictEqual(moves.at(-1).fromIndex, 0);
    assert.strictEqual(moves.at(-1).toIndex, 1);
  });

  test("frozen rows keep their exact visible slots", async function (assert) {
    // The invariant the interleaving exists for: "pinned" never moves, and the
    // movable items refill the remaining slots in their new order.
    const { engine, moves } = engineFor([
      { id: "a" },
      { id: "pinned", movable: false },
      { id: "b" },
      { id: "c" },
    ]);

    engine.move("a", "bottom", "menu");

    assert.deepEqual(
      moves.at(-1).proposedToItems,
      ["b", "pinned", "c", "a"],
      "the frozen row holds index 1 while the movable slots refill around it"
    );
  });

  test("a move to an end that the row already occupies is a no-op", async function (assert) {
    const { engine, moves } = engineFor([{ id: "a" }, { id: "b" }]);

    engine.move("a", "top", "menu");
    engine.move("a", "up", "menu");

    assert.deepEqual(moves, [], "neither reports a move nor a projection");
  });

  test("a frozen row refuses to move at all", async function (assert) {
    const { engine, moves } = engineFor([
      { id: "a", movable: false },
      { id: "b" },
    ]);

    engine.move("a", "down", "menu");

    assert.deepEqual(moves, []);
  });

  test("an onMove false return still commits, and only gates the announcement", async function (assert) {
    let announced = 0;
    const rows = rowsFor([{ id: "a" }, { id: "b" }]);
    const seen = [];
    const engine = new MoveEngine({
      args: () => ({
        items: ["a", "b"],
        onMove: (move) => {
          seen.push(move);
          return false;
        },
      }),
      rows: () => rows,
      listId: () => "default",
      announcer: {
        announceMove() {
          announced += 1;
        },
        announceBoundary() {},
        noteRun() {},
        updateRun() {},
        cancelRun() {},
      },
      refocusIndex() {},
    });

    engine.move("a", "down", "menu");

    assert.strictEqual(seen.length, 1, "the consumer is still told");
    assert.strictEqual(announced, 0, "but the veto stops the announcement");
  });

  test("removalProjection leaves frozen rows on their own indices", async function (assert) {
    const { engine } = engineFor([
      { id: "a" },
      { id: "pinned", movable: false },
      { id: "b" },
      { id: "c" },
    ]);

    const removal = engine.removalProjection("a");

    assert.strictEqual(removal.item, "a");
    assert.strictEqual(removal.fromIndex, 0);
    assert.deepEqual(
      removal.proposedFromItems,
      ["b", "pinned", "c"],
      "the list shrinks by its last slot and the frozen row keeps index 1"
    );
  });

  test("removalProjection refuses a key it does not own or cannot move", async function (assert) {
    const { engine } = engineFor([{ id: "a", movable: false }, { id: "b" }]);

    assert.strictEqual(engine.removalProjection("a"), undefined, "frozen");
    assert.strictEqual(engine.removalProjection("nope"), undefined, "unknown");
  });

  test("rev42618 removalProjection keeps a frozen final row", async function (assert) {
    // "pinned" sits on the final visible index, the one slot the shrinking
    // list no longer has, so it must join the end of the refill queue.
    const { engine } = engineFor([
      { id: "a" },
      { id: "b" },
      { id: "pinned", movable: false },
    ]);

    const removal = engine.removalProjection("a");

    assert.deepEqual(
      removal.proposedFromItems,
      ["b", "pinned"],
      "the frozen row whose slot was dropped joins the end instead of vanishing"
    );
    assert.strictEqual(
      removal.proposedFromItems.length,
      2,
      "the list shrinks by exactly one slot"
    );
    assert.deepEqual(
      [...removal.proposedFromItems].sort(),
      ["a", "b", "pinned"].filter((item) => item !== "a").sort(),
      "conservation: the projection holds exactly the original items minus the removed one"
    );
  });

  test("rev42618 commitCrossMove keeps a frozen destination row on its slot", async function (assert) {
    const crossMoves = [];
    const sourceMember = {
      listId: "source",
      listLabel: () => "Source",
      disabled: () => false,
      getItems: () => ["arrival"],
      element: () => undefined,
      removalProjection: (key) =>
        key === "arrival"
          ? { item: "arrival", fromIndex: 0, proposedFromItems: [] }
          : undefined,
      acceptMove() {},
    };
    const group = {
      token: "token",
      generation: () => 0,
      registerMember: () => () => {},
      lookupMember: (listId) =>
        listId === "source" ? sourceMember : undefined,
      siblings: () => [],
      neighbour: () => undefined,
      onMove: (move) => crossMoves.push(move),
    };
    const { engine } = engineFor(
      [{ id: "x" }, { id: "pinned", movable: false }, { id: "y" }],
      { group }
    );

    engine.commitCrossMove("source", "arrival", 2, "menu");

    const move = crossMoves.at(-1);
    assert.strictEqual(
      move.proposedToItems[1],
      "pinned",
      "the frozen destination row keeps its original visible index while the list grows"
    );
    assert.strictEqual(
      move.proposedToItems[move.toIndex],
      "arrival",
      "the arriving item sits exactly where the move reports it landed"
    );
    assert.deepEqual(
      [...move.proposedToItems].sort(),
      ["x", "pinned", "y", "arrival"].sort(),
      "conservation: the destination holds exactly its own items plus the arriving one"
    );
  });
});
