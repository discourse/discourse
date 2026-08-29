import { tracked } from "@glimmer/tracking";
import { trackedArray } from "@ember/reactive/collections";
import {
  click,
  find,
  render,
  resetOnerror,
  settled,
  setupOnerror,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DMenus from "discourse/float-kit/components/d-menus";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { simulateDrag } from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";
import {
  dropCoordinates,
  INDEX_KEY,
  label,
  noop,
  objectItems,
  renderedItemOrder,
} from "discourse/tests/helpers/ui-kit/reorderable-list-fixtures";
import {
  moveItemSelector,
  moveVia,
  moveViaChord,
  openMoveMenu,
  rowSelector,
} from "discourse/tests/helpers/ui-kit/reorderable-list-helper";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import DReorderableListGroup from "discourse/ui-kit/d-reorderable-list-group";

/**
 * Supplemental invariant suite for `DReorderableList`, written blind against
 * the public contract in `types.ts`. It pins cross-cutting guarantees —
 * conservation, frozen-row pinning, path agreement, announcement/DOM
 * correspondence, audible refusals, focus retention — rather than restating
 * individual fixes.
 */

/** The comparable identity of one item, object or primitive. */
function idOf(item) {
  return item?.id ?? String(item);
}

/** The identity multiset of one or more item lists, as `{ id: count }`. */
function multiset(lists) {
  const counts = {};
  for (const list of lists) {
    for (const item of list) {
      const id = idOf(item);
      counts[id] = (counts[id] ?? 0) + 1;
    }
  }
  return counts;
}

/**
 * Asserts that one committed move's payload conserves the item multiset: the
 * proposed orders hold exactly the items the visible lists held, nothing
 * duplicated and nothing lost, whether the move stayed in one list or crossed.
 */
function assertConserved(assert, move, context) {
  const crossList = move.fromList !== move.toList;
  const before = crossList
    ? multiset([move.fromItems, move.toItems])
    : multiset([move.fromItems]);
  const after = crossList
    ? multiset([move.proposedFromItems, move.proposedToItems])
    : multiset([move.proposedToItems]);
  assert.deepEqual(
    after,
    before,
    `${context}: the proposed orders hold exactly the items the lists held, nothing duplicated or lost`
  );
}

/**
 * The last announced "position N of M", parsed. Terse in-run fragments like
 * "2 of 3" deliberately do not match; only the settled sentence does.
 */
function lastSpokenPosition(announce) {
  const spoken = announce
    .getCalls()
    .map((call) => call.args[0])
    .filter((text) => /position \d+ of \d+/.test(text))
    .at(-1);
  const match = /position (\d+) of (\d+)/.exec(spoken ?? "");
  return match && { position: Number(match[1]), total: Number(match[2]) };
}

/**
 * A tracked two-member group store with the applier a real consumer writes:
 * the component proposes orders and the store adopts them. Member listIds are
 * `"first"` and `"second"`.
 */
function groupStore(firstItems, secondItems) {
  const first = trackedArray(firstItems);
  const second = trackedArray(secondItems);
  const moves = [];
  const applyMove = (move) => {
    moves.push(move);
    const listFor = (listId) => (listId === "first" ? first : second);
    const from = listFor(move.fromList);
    from.splice(0, from.length, ...move.proposedFromItems);
    if (move.toList !== move.fromList) {
      const to = listFor(move.toList);
      to.splice(0, to.length, ...move.proposedToItems);
    }
  };
  return { first, second, moves, applyMove };
}

/** A tracked standalone list store whose applier adopts each proposed order. */
function listStore(initialItems) {
  const items = trackedArray(initialItems);
  const moves = [];
  const applyMove = (move) => {
    moves.push(move);
    items.splice(0, items.length, ...move.proposedToItems);
  };
  return { items, moves, applyMove };
}

module(
  "Integration | ui-kit | DReorderableList | supplemental",
  function (hooks) {
    setupRenderingTest(hooks);

    test("supp42618 every committed move conserves the item multiset across all involved lists", async function (assert) {
      const { first, second, moves, applyMove } = groupStore(
        [
          { id: "f-one", name: "F One" },
          { id: "f-two", name: "F Two" },
          { id: "f-three", name: "F Three" },
        ],
        [
          { id: "s-one", name: "S One" },
          { id: "s-two", name: "S Two" },
        ]
      );
      const initialUnion = multiset([first, second]);

      await render(
        <template>
          <DMenus />
          <DReorderableListGroup @onMove={{applyMove}} as |group|>
            <DReorderableList
              @group={{group}}
              @listId="first"
              @listLabel="First"
              @spill={{true}}
              @items={{first}}
              @key="id"
              @label={{label}}
              class="supp-first"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
            <DReorderableList
              @group={{group}}
              @listId="second"
              @listLabel="Second"
              @spill={{true}}
              @items={{second}}
              @key="id"
              @label={{label}}
              class="supp-second"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );

      await moveVia("f-two", "up", ".supp-first");

      assert.strictEqual(
        moves.length,
        1,
        "the in-list menu move commits exactly once"
      );
      assert.strictEqual(
        moves.at(-1).method,
        "menu",
        "the first operation really travelled the menu path"
      );
      assert.strictEqual(
        moves.at(-1).fromList,
        moves.at(-1).toList,
        "and stayed inside one list"
      );
      assertConserved(assert, moves.at(-1), "in-list menu move");

      const dragSource = rowSelector("f-three", ".supp-first");
      const dragTarget = rowSelector("s-one", ".supp-second");
      await simulateDrag(dragSource, dragTarget, {
        dataTransfer: new DataTransfer(),
        targetCoordinates: dropCoordinates(dragTarget, "before"),
      });

      assert.strictEqual(
        moves.length,
        2,
        "the cross-list drag commits exactly once"
      );
      assert.strictEqual(
        moves.at(-1).method,
        "drag",
        "the second operation really travelled the drag path"
      );
      assert.notStrictEqual(
        moves.at(-1).fromList,
        moves.at(-1).toList,
        "and crossed lists"
      );
      assertConserved(assert, moves.at(-1), "cross-list drag");

      await moveVia("s-two", "list", ".supp-second");

      assert.strictEqual(
        moves.length,
        3,
        "the cross-list menu move commits exactly once"
      );
      assert.strictEqual(
        moves.at(-1).method,
        "menu",
        "the third operation really travelled the menu path"
      );
      assert.notStrictEqual(
        moves.at(-1).fromList,
        moves.at(-1).toList,
        "and crossed lists"
      );
      assertConserved(assert, moves.at(-1), "cross-list menu move");

      const lastFirstKey = renderedItemOrder(".supp-first").at(-1);
      await moveViaChord(lastFirstKey, "down", ".supp-first");

      assert.strictEqual(
        moves.length,
        4,
        "the keyboard spill commits exactly once"
      );
      assert.strictEqual(
        moves.at(-1).method,
        "keyboard",
        "the fourth operation really travelled the keyboard path"
      );
      assert.notStrictEqual(
        moves.at(-1).fromList,
        moves.at(-1).toList,
        "and spilled across the member boundary"
      );
      assertConserved(assert, moves.at(-1), "keyboard spill");

      assert.deepEqual(
        multiset([first, second]),
        initialUnion,
        "after all four input methods the live stores still hold exactly the original items"
      );
      assert.deepEqual(
        multiset([
          renderedItemOrder(".supp-first"),
          renderedItemOrder(".supp-second"),
        ]),
        initialUnion,
        "and the rendered rows across both lists are the same multiset the page started with"
      );
    });

    test("supp42618 frozen rows at the first, middle, and last index hold their slots through in-list moves", async function (assert) {
      const { items, moves, applyMove } = listStore([
        { id: "pin-first", name: "Pin First" },
        { id: "mov-a", name: "Mov A" },
        { id: "pin-mid", name: "Pin Mid" },
        { id: "mov-b", name: "Mov B" },
        { id: "pin-last", name: "Pin Last" },
      ]);
      const movable = (item) => item.id.startsWith("mov");
      const pinnedSlots = { "pin-first": 0, "pin-mid": 2, "pin-last": 4 };

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @movable={{movable}}
            @onMove={{applyMove}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      await moveVia("mov-a", "bottom");

      assert.strictEqual(moves.length, 1, "the bottom move commits once");
      for (const [id, slot] of Object.entries(pinnedSlots)) {
        assert.strictEqual(
          moves.at(-1).proposedToItems.findIndex((item) => item.id === id),
          slot,
          `${id} keeps visible index ${slot} in the proposal while a row moves to the bottom past it`
        );
      }
      assert.deepEqual(
        renderedItemOrder(),
        ["pin-first", "mov-b", "pin-mid", "mov-a", "pin-last"],
        "the movable rows traded places around all three pinned slots"
      );

      await moveViaChord("mov-a", "top");

      assert.strictEqual(moves.length, 2, "the top chord commits once");
      for (const [id, slot] of Object.entries(pinnedSlots)) {
        assert.strictEqual(
          moves.at(-1).proposedToItems.findIndex((item) => item.id === id),
          slot,
          `${id} keeps visible index ${slot} in the proposal while a row moves to the top past it`
        );
      }
      assert.deepEqual(
        renderedItemOrder(),
        ["pin-first", "mov-a", "pin-mid", "mov-b", "pin-last"],
        "the round trip left every frozen row exactly where it started"
      );
    });

    test("supp42618 frozen edge rows hold their slots when an item leaves one list and enters another", async function (assert) {
      const { first, second, moves, applyMove } = groupStore(
        [
          { id: "src-pin", name: "Src Pin" },
          { id: "src-a", name: "Src A" },
          { id: "src-b", name: "Src B" },
        ],
        [
          { id: "dst-a", name: "Dst A" },
          { id: "dst-b", name: "Dst B" },
          { id: "dst-pin", name: "Dst Pin" },
        ]
      );
      const movable = (item) => !item.id.endsWith("pin");

      await render(
        <template>
          <DMenus />
          <DReorderableListGroup @onMove={{applyMove}} as |group|>
            <DReorderableList
              @group={{group}}
              @listId="first"
              @listLabel="Source"
              @items={{first}}
              @key="id"
              @label={{label}}
              @movable={{movable}}
              class="fz-source"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
            <DReorderableList
              @group={{group}}
              @listId="second"
              @listLabel="Destination"
              @items={{second}}
              @key="id"
              @label={{label}}
              @movable={{movable}}
              class="fz-destination"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );

      const source = rowSelector("src-a", ".fz-source");
      const target = rowSelector("dst-a", ".fz-destination");
      await simulateDrag(source, target, {
        dataTransfer: new DataTransfer(),
        targetCoordinates: dropCoordinates(target, "after"),
      });

      assert.strictEqual(moves.length, 1, "the cross-list drop commits once");
      const move = moves[0];
      assertConserved(assert, move, "cross-list drop between frozen edges");

      assert.strictEqual(
        move.proposedFromItems.findIndex((item) => item.id === "src-pin"),
        0,
        "a frozen first row keeps visible index 0 when a movable row leaves its list"
      );
      assert.strictEqual(
        move.proposedFromItems.length,
        2,
        "the source proposal shrank by exactly the departed row"
      );
      assert.strictEqual(
        move.proposedToItems.length,
        4,
        "the destination proposal grew by exactly the arriving row"
      );
      assert.strictEqual(
        move.proposedToItems.findIndex((item) => item.id === "dst-pin"),
        2,
        "a frozen LAST row keeps visible index 2 when an arrival grows the list, rather than being carried to the new end"
      );
      assert.true(
        move.proposedToItems.some((item) => item.id === "src-a"),
        "and the arrival itself is present in the destination proposal"
      );

      assert.strictEqual(
        renderedItemOrder(".fz-source").indexOf("src-pin"),
        0,
        "after the host applies the move, the source's frozen row still renders first"
      );
      assert.strictEqual(
        renderedItemOrder(".fz-destination").indexOf("dst-pin"),
        2,
        "and the destination's frozen row still renders at its original index"
      );
      assert.strictEqual(
        renderedItemOrder(".fz-destination").length,
        4,
        "with the destination holding all four rows"
      );
    });

    test("supp42618 drag, menu, and chord produce identical results for the same logical move", async function (assert) {
      const makeStore = () => {
        const items = trackedArray(objectItems());
        const store = { items, committed: [] };
        store.onMove = (move) => {
          store.committed.push(move.proposedToItems.map((item) => item.id));
          items.splice(0, items.length, ...move.proposedToItems);
        };
        return store;
      };
      const dragStore = makeStore();
      const menuStore = makeStore();
      const chordStore = makeStore();
      const dragItems = dragStore.items;
      const menuItems = menuStore.items;
      const chordItems = chordStore.items;
      const dragMove = dragStore.onMove;
      const menuMove = menuStore.onMove;
      const chordMove = chordStore.onMove;

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{dragItems}}
            @key="id"
            @label={{label}}
            @onMove={{dragMove}}
            id="agree-drag"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
          <DReorderableList
            @items={{menuItems}}
            @key="id"
            @label={{label}}
            @onMove={{menuMove}}
            id="agree-menu"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
          <DReorderableList
            @items={{chordItems}}
            @key="id"
            @label={{label}}
            @onMove={{chordMove}}
            id="agree-chord"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      // The same logical move — bravo one step down — issued three ways
      // against three identical starting states.
      const dragSource = rowSelector("bravo", "#agree-drag");
      const dragTarget = rowSelector("charlie", "#agree-drag");
      await simulateDrag(dragSource, dragTarget, {
        dataTransfer: new DataTransfer(),
        targetCoordinates: dropCoordinates(dragTarget, "after"),
      });
      await moveVia("bravo", "down", "#agree-menu");
      await moveViaChord("bravo", "down", "#agree-chord");

      assert.strictEqual(
        dragStore.committed.length,
        1,
        "the drag committed its move exactly once"
      );
      const agreed = dragStore.committed[0];
      assert.deepEqual(
        menuStore.committed,
        [agreed],
        "the menu path committed once and proposed exactly the order the drag proposed"
      );
      assert.deepEqual(
        chordStore.committed,
        [agreed],
        "the chord path committed once and proposed exactly the order the drag proposed"
      );
      assert.deepEqual(
        renderedItemOrder("#agree-drag"),
        agreed,
        "the drag-driven list renders the agreed order"
      );
      assert.deepEqual(
        renderedItemOrder("#agree-menu"),
        agreed,
        "the menu-driven list renders the agreed order"
      );
      assert.deepEqual(
        renderedItemOrder("#agree-chord"),
        agreed,
        "the chord-driven list renders the agreed order"
      );
    });

    test("supp42618 an in-list announcement names the position the row actually occupies", async function (assert) {
      const { items, applyMove } = listStore(objectItems());
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{applyMove}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      await moveVia("alpha", "down");

      const menuSpoken = lastSpokenPosition(announce);
      assert.notStrictEqual(
        menuSpoken,
        null,
        "the menu move announced a position at all, so the correspondence is checkable"
      );
      assert.strictEqual(
        renderedItemOrder()[menuSpoken?.position - 1],
        "alpha",
        "the rendered row at the announced menu-move position is the row that moved"
      );
      assert.strictEqual(
        menuSpoken?.total,
        renderedItemOrder().length,
        "and the announced total is the number of rows actually rendered"
      );

      announce.resetHistory();
      await moveViaChord("charlie", "top");

      const chordSpoken = lastSpokenPosition(announce);
      assert.notStrictEqual(
        chordSpoken,
        null,
        "the chord move announced a position at all, so the correspondence is checkable"
      );
      assert.strictEqual(
        renderedItemOrder()[chordSpoken?.position - 1],
        "charlie",
        "the rendered row at the announced chord-move position is the row that moved"
      );
      assert.strictEqual(
        chordSpoken?.total,
        renderedItemOrder().length,
        "and the chord announcement's total matches the rendered row count"
      );
    });

    test("supp42618 a cross-list announcement names the slot the item occupies beside a frozen row", async function (assert) {
      const movable = (item) => item.id !== "an-dst-pin";
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
      const store = groupStore(
        [
          { id: "an-src-a", name: "An Src A" },
          { id: "an-src-b", name: "An Src B" },
        ],
        [
          { id: "an-dst-a", name: "An Dst A" },
          { id: "an-dst-pin", name: "An Dst Pin" },
        ]
      );
      const storeFirst = store.first;
      const storeSecond = store.second;
      const storeApply = store.applyMove;

      await render(
        <template>
          <DMenus />
          <DReorderableListGroup @onMove={{storeApply}} as |group|>
            <DReorderableList
              @group={{group}}
              @listId="first"
              @listLabel="Announce source"
              @items={{storeFirst}}
              @key="id"
              @label={{label}}
              @movable={{movable}}
              class="an-source"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
            <DReorderableList
              @group={{group}}
              @listId="second"
              @listLabel="Announce target"
              @items={{storeSecond}}
              @key="id"
              @label={{label}}
              @movable={{movable}}
              class="an-target"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );

      const source = rowSelector("an-src-a", ".an-source");
      const target = rowSelector("an-dst-a", ".an-target");
      await simulateDrag(source, target, {
        dataTransfer: new DataTransfer(),
        targetCoordinates: dropCoordinates(target, "after"),
      });

      assert.strictEqual(
        store.moves.length,
        1,
        "the cross-list drop into the frozen-holding destination commits once"
      );
      const spoken = lastSpokenPosition(announce);
      assert.notStrictEqual(
        spoken,
        null,
        "the cross-list move announced a position at all, so the correspondence is checkable"
      );
      assert.strictEqual(
        renderedItemOrder(".an-target")[spoken?.position - 1],
        "an-src-a",
        "the rendered destination row at the announced position is the item that arrived, even with a frozen row holding a slot it might naively have been given"
      );
      assert.strictEqual(
        spoken?.total,
        renderedItemOrder(".an-target").length,
        "and the announced total is the destination's actual rendered row count"
      );
    });

    test("supp42618 the announced position stays truthful among equal primitive values", async function (assert) {
      const { items, moves, applyMove } = listStore([
        "Alpha",
        "Bravo",
        "Alpha",
      ]);
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key={{INDEX_KEY}}
            @label={{label}}
            @onMove={{applyMove}}
          >
            <:row as |item|>
              <span data-test-item={{item}}>{{item}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      await moveVia("0", "down");

      assert.strictEqual(
        moves.length,
        1,
        "moving one of two equal values commits exactly once"
      );
      const spoken = lastSpokenPosition(announce);
      assert.notStrictEqual(
        spoken,
        null,
        "the move among duplicates announced a position at all, so the correspondence is checkable"
      );
      assert.strictEqual(
        spoken?.position,
        moves[0].toIndex + 1,
        "the announced position is the committed landing index, not the slot of the other equal value"
      );
      assert.strictEqual(
        renderedItemOrder()[spoken?.position - 1],
        "Alpha",
        "and the rendered row at the announced position holds the moved value"
      );
      assert.deepEqual(
        multiset([items]),
        { Alpha: 2, Bravo: 1 },
        "with both equal values surviving the move, neither merged nor duplicated"
      );
    });

    test("supp42618 a refused boundary chord leaves the order alone and says so", async function (assert) {
      const store = listStore(objectItems());
      const items = store.items;
      const apply = store.applyMove;
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{apply}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      await moveViaChord("charlie", "down");

      assert.strictEqual(
        store.moves.length,
        0,
        "the boundary refusal commits nothing"
      );
      assert.deepEqual(
        renderedItemOrder(),
        ["alpha", "bravo", "charlie"],
        "and the rendered order is untouched"
      );
      assert.strictEqual(
        announce.callCount,
        1,
        "yet the explicit command was answered exactly once"
      );
      const spokenText = String(announce.firstCall.args[0]);
      assert.true(spokenText.length > 0, "with a non-empty explanation");
      assert.true(
        spokenText.includes("Charlie"),
        "that names the row the reader tried to move"
      );
    });

    test("supp42618 a spill aimed at a disabled member commits nothing and says so", async function (assert) {
      const first = trackedArray([
        { id: "dis-a", name: "Dis A" },
        { id: "dis-b", name: "Dis B" },
      ]);
      const second = trackedArray([{ id: "dis-c", name: "Dis C" }]);
      const onMove = sinon.spy();
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
      let raised;

      setupOnerror((error) => {
        raised = error;
      });

      try {
        await render(
          <template>
            <DMenus />
            <DReorderableListGroup @onMove={{onMove}} as |group|>
              <DReorderableList
                @group={{group}}
                @listId="first"
                @listLabel="Enabled"
                @spill={{true}}
                @items={{first}}
                @key="id"
                @label={{label}}
                class="dis-first"
              >
                <:row as |item|>
                  <span data-test-item={{item.id}}>{{item.name}}</span>
                </:row>
              </DReorderableList>
              <DReorderableList
                @group={{group}}
                @listId="second"
                @listLabel="Disabled"
                @spill={{true}}
                @disabled={{true}}
                @items={{second}}
                @key="id"
                @label={{label}}
                class="dis-second"
              >
                <:row as |item|>
                  <span data-test-item={{item.id}}>{{item.name}}</span>
                </:row>
              </DReorderableList>
            </DReorderableListGroup>
          </template>
        );

        await moveViaChord("dis-b", "down", ".dis-first");
      } finally {
        resetOnerror();
      }

      assert.strictEqual(
        raised,
        undefined,
        "spilling toward a disabled member raises no error"
      );
      assert.strictEqual(
        onMove.callCount,
        0,
        "and commits no move into a list that is read-only"
      );
      assert.deepEqual(
        renderedItemOrder(".dis-first"),
        ["dis-a", "dis-b"],
        "the source order is unchanged"
      );
      assert.deepEqual(
        renderedItemOrder(".dis-second"),
        ["dis-c"],
        "the disabled destination is unchanged"
      );
      assert.strictEqual(
        announce.callCount,
        1,
        "yet the refused command is answered exactly once"
      );
      assert.true(
        String(announce.firstCall.args[0]).includes("Dis B"),
        "with an explanation naming the row that could not go"
      );
    });

    test("supp42618 choosing a destination that unmounted mid-menu commits nothing and says so", async function (assert) {
      const firstItems = [
        { id: "st-a", name: "St A" },
        { id: "st-b", name: "St B" },
      ];
      const secondItems = [{ id: "st-c", name: "St C" }];
      const state = new (class {
        @tracked showSecond = true;
      })();
      const onMove = sinon.spy();
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
      let raised;

      setupOnerror((error) => {
        raised = error;
      });

      try {
        await render(
          <template>
            <DMenus />
            <DReorderableListGroup @onMove={{onMove}} as |group|>
              <DReorderableList
                @group={{group}}
                @listId="first"
                @listLabel="Stale source"
                @items={{firstItems}}
                @key="id"
                @label={{label}}
                class="stale-first"
              >
                <:row as |item|>
                  <span data-test-item={{item.id}}>{{item.name}}</span>
                </:row>
              </DReorderableList>
              {{#if state.showSecond}}
                <DReorderableList
                  @group={{group}}
                  @listId="second"
                  @listLabel="Stale target"
                  @items={{secondItems}}
                  @key="id"
                  @label={{label}}
                  class="stale-second"
                >
                  <:row as |item|>
                    <span data-test-item={{item.id}}>{{item.name}}</span>
                  </:row>
                </DReorderableList>
              {{/if}}
            </DReorderableListGroup>
          </template>
        );

        await openMoveMenu("st-a", ".stale-first");
        assert
          .dom(moveItemSelector("list"))
          .exists("the destination is offered while its list is mounted");

        state.showSecond = false;
        await settled();

        assert
          .dom(".stale-second")
          .doesNotExist("the destination list is fully unrendered");
        assert
          .dom(moveItemSelector("list"))
          .exists(
            "the already-open menu still shows the destination the reader was considering"
          );

        await click(moveItemSelector("list"));
      } finally {
        resetOnerror();
      }

      assert.strictEqual(
        raised,
        undefined,
        "choosing the stale destination raises no error"
      );
      assert.strictEqual(
        onMove.callCount,
        0,
        "and commits nothing to a list that no longer exists"
      );
      assert.deepEqual(
        renderedItemOrder(".stale-first"),
        ["st-a", "st-b"],
        "the source order is unchanged"
      );
      assert.strictEqual(
        announce.callCount,
        1,
        "yet the explicit command is answered exactly once"
      );
      assert.true(
        String(announce.firstCall.args[0]).length > 0,
        "with a non-empty explanation rather than silence"
      );
    });

    test("supp42618 focus stays inside the surface after in-list and cross-list commits", async function (assert) {
      const store = groupStore(
        [
          { id: "mf-a", name: "Mf A" },
          { id: "mf-b", name: "Mf B" },
        ],
        [
          { id: "mf-pin", name: "Mf Pin" },
          { id: "mf-c", name: "Mf C" },
        ]
      );
      const storeFirst = store.first;
      const storeSecond = store.second;
      const storeApply = store.applyMove;
      const movable = (item) => item.id !== "mf-pin";

      await render(
        <template>
          <DMenus />
          <div id="move-focus-arena">
            <DReorderableListGroup @onMove={{storeApply}} as |group|>
              <DReorderableList
                @group={{group}}
                @listId="first"
                @listLabel="Focus first"
                @items={{storeFirst}}
                @key="id"
                @label={{label}}
                @movable={{movable}}
                class="mf-first"
              >
                <:row as |item|>
                  <span data-test-item={{item.id}}>{{item.name}}</span>
                </:row>
              </DReorderableList>
              <DReorderableList
                @group={{group}}
                @listId="second"
                @listLabel="Focus second"
                @items={{storeSecond}}
                @key="id"
                @label={{label}}
                @movable={{movable}}
                class="mf-second"
              >
                <:row as |item|>
                  <span data-test-item={{item.id}}>{{item.name}}</span>
                </:row>
              </DReorderableList>
            </DReorderableListGroup>
          </div>
        </template>
      );

      const arena = find("#move-focus-arena");

      await moveViaChord("mf-a", "down", ".mf-first");

      assert.strictEqual(store.moves.length, 1, "the in-list chord committed");
      assert.notStrictEqual(
        document.activeElement,
        document.body,
        "an in-list commit does not dump focus onto the body"
      );
      assert.true(
        arena.contains(document.activeElement),
        "focus is still somewhere inside the reordering surface after the in-list move"
      );

      await moveVia("mf-a", "list", ".mf-first");

      assert.strictEqual(
        store.moves.length,
        2,
        "the cross-list menu move committed"
      );
      assert.strictEqual(
        renderedItemOrder(".mf-second").indexOf("mf-pin"),
        0,
        "the destination's frozen first row still holds index 0 after the arrival"
      );
      assert.notStrictEqual(
        document.activeElement,
        document.body,
        "a cross-list commit into a frozen-first list does not dump focus onto the body"
      );
      assert.true(
        arena.contains(document.activeElement),
        "focus is still somewhere inside the reordering surface after the cross-list move"
      );
    });

    test("supp42618 focus stays inside the list as removals empty it", async function (assert) {
      const state = new (class {
        @tracked
        items = [
          { id: "rm-pin", name: "Rm Pin" },
          { id: "rm-a", name: "Rm A" },
          { id: "rm-b", name: "Rm B" },
        ];
      })();
      const movable = (item) => item.id !== "rm-pin";
      const removable = (item) => item.id !== "rm-pin";
      const onRemove = (item) => {
        state.items = state.items.filter((candidate) => candidate !== item);
      };

      await render(
        <template>
          <DMenus />
          <div id="remove-focus-arena">
            <DReorderableList
              @items={{state.items}}
              @key="id"
              @label={{label}}
              @onMove={{noop}}
              @movable={{movable}}
              @removable={{removable}}
              @onRemove={{onRemove}}
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </div>
        </template>
      );

      const arena = find("#remove-focus-arena");

      await click(`${rowSelector("rm-a")} .d-reorderable-list__remove`);

      assert.deepEqual(
        renderedItemOrder(),
        ["rm-pin", "rm-b"],
        "the middle row really went"
      );
      assert.notStrictEqual(
        document.activeElement,
        document.body,
        "removing a middle row does not dump focus onto the body"
      );
      assert.true(
        arena.contains(document.activeElement),
        "focus is still inside the list after the middle removal"
      );

      await click(`${rowSelector("rm-b")} .d-reorderable-list__remove`);

      assert.deepEqual(
        renderedItemOrder(),
        ["rm-pin"],
        "the last removable row really went"
      );
      assert.notStrictEqual(
        document.activeElement,
        document.body,
        "removing the last removable row does not dump focus onto the body"
      );
      assert.true(
        arena.contains(document.activeElement),
        "focus is still inside the list even with no removable rows left to hold it"
      );
    });

    test("supp42618 an index-keyed cross-list move between equal values neither throws nor corrupts", async function (assert) {
      const store = groupStore(["Alpha", "Bravo"], ["Alpha", "Charlie"]);
      const storeFirst = store.first;
      const storeSecond = store.second;
      const storeApply = store.applyMove;
      const initialUnion = multiset([storeFirst, storeSecond]);
      let raised;

      setupOnerror((error) => {
        raised = error;
      });

      try {
        await render(
          <template>
            <DMenus />
            <DReorderableListGroup @onMove={{storeApply}} as |group|>
              <DReorderableList
                @group={{group}}
                @listId="first"
                @listLabel="Eq first"
                @items={{storeFirst}}
                @key={{INDEX_KEY}}
                @label={{label}}
                class="eq-first"
              >
                <:row as |item|>
                  <span data-test-item={{item}}>{{item}}</span>
                </:row>
              </DReorderableList>
              <DReorderableList
                @group={{group}}
                @listId="second"
                @listLabel="Eq second"
                @items={{storeSecond}}
                @key={{INDEX_KEY}}
                @label={{label}}
                class="eq-second"
              >
                <:row as |item|>
                  <span data-test-item={{item}}>{{item}}</span>
                </:row>
              </DReorderableList>
            </DReorderableListGroup>
          </template>
        );

        const source = rowSelector("0", ".eq-first");
        const target = rowSelector("1", ".eq-second");
        await simulateDrag(source, target, {
          dataTransfer: new DataTransfer(),
          targetCoordinates: dropCoordinates(target, "before"),
        });
      } finally {
        resetOnerror();
      }

      assert.strictEqual(
        raised,
        undefined,
        "dragging an index-keyed value into a list holding an equal value raises no error"
      );
      assert.true(
        store.moves.length <= 1,
        "at most the one commanded move commits, never a cascade"
      );
      assert.deepEqual(
        multiset([storeFirst, storeSecond]),
        initialUnion,
        "the live stores still hold exactly the original values, so the equal values neither merged nor duplicated"
      );
      assert.deepEqual(
        multiset([
          renderedItemOrder(".eq-first"),
          renderedItemOrder(".eq-second"),
        ]),
        initialUnion,
        "and the rendered rows across both lists are the same multiset the page started with"
      );
      for (const committed of store.moves) {
        assertConserved(
          assert,
          committed,
          "index-keyed cross-list move between equal values"
        );
        assert.strictEqual(
          committed.item,
          "Alpha",
          "the committed move resolved the dragged duplicate's value, not some other row"
        );
      }
    });

    test("supp42618 replacing the items under an open menu neither throws nor commits", async function (assert) {
      const state = new (class {
        @tracked items = objectItems();
      })();
      const replacement = [
        { id: "rep-a", name: "Rep A" },
        { id: "rep-b", name: "Rep B" },
      ];
      const onMove = sinon.spy();
      let raised;

      setupOnerror((error) => {
        raised = error;
      });

      try {
        await render(
          <template>
            <DMenus />
            <DReorderableList
              @items={{state.items}}
              @key="id"
              @label={{label}}
              @onMove={{onMove}}
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </template>
        );

        await openMoveMenu("bravo");
        assert
          .dom(moveItemSelector("up"))
          .exists("the menu opened over the row before the swap");

        state.items = replacement;
        await settled();

        // The component may close the stale menu itself or leave it to be
        // chosen; either way choosing must not commit against the old items.
        const staleDestination = find(moveItemSelector("up"));
        if (staleDestination) {
          await click(staleDestination);
        }
      } finally {
        resetOnerror();
      }

      assert.strictEqual(
        raised,
        undefined,
        "swapping the whole collection under an open menu raises no error"
      );
      assert.strictEqual(
        onMove.callCount,
        0,
        "and no move commits for a row that no longer exists"
      );
      assert.deepEqual(
        renderedItemOrder(),
        ["rep-a", "rep-b"],
        "the list renders the replacement collection intact"
      );
    });
  }
);
