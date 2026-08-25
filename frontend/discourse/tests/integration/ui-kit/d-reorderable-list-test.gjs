import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { trackedArray } from "@ember/reactive/collections";
import {
  click,
  fillIn,
  find,
  findAll,
  focus,
  render,
  resetOnerror,
  settled,
  setupOnerror,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DMenus from "discourse/float-kit/components/d-menus";
import loadAccessibleName from "discourse/lib/load-accessible-name";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  centerOf,
  dragEvent,
  simulateDrag,
  simulateUntargetedDrag,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import DReorderableListGroup from "discourse/ui-kit/d-reorderable-list-group";

const noop = () => {};
const INDEX_KEY = "@index";
const label = (item) => item.name ?? String(item);

function objectItems() {
  return [
    { id: "alpha", identity: { value: "alpha-key" }, name: "Alpha" },
    { id: "bravo", identity: { value: "bravo-key" }, name: "Bravo" },
    { id: "charlie", identity: { value: "charlie-key" }, name: "Charlie" },
  ];
}

function rowSelector(key, root = "") {
  const prefix = root ? `${root} ` : "";
  return `${prefix}[data-reorderable-key="${key}"]`;
}

function handleSelector(key, root = "") {
  return `${rowSelector(key, root)} .d-reorderable-list__handle`;
}

function moveItemSelector(target) {
  return `.d-reorderable-list__move-item.--${target}`;
}

/** Opens one row's move menu, leaving it open for inspection. */
async function openMoveMenu(key, root = "") {
  await click(handleSelector(key, root));
}

/**
 * Drives a move the way a pointer user does: open the row's menu, choose a
 * destination. The menu closes itself, so this leaves no state behind.
 */
async function moveVia(key, target, root = "") {
  await openMoveMenu(key, root);
  await click(moveItemSelector(target));
}

/** Drives a move the way the keyboard accelerator does. */
async function moveViaChord(key, target, root = "") {
  const handle = find(handleSelector(key, root));
  handle.focus();
  const chordKey = {
    up: "ArrowUp",
    down: "ArrowDown",
    top: "Home",
    end: "End",
  }[target];
  await triggerKeyEvent(handle, "keydown", chordKey, { altKey: true });
}

function renderedItemOrder(root = "") {
  const prefix = root ? `${root} ` : "";
  return findAll(`${prefix}[data-test-item]`).map(
    (element) => element.dataset.testItem
  );
}

function dropCoordinates(targetSelector, position) {
  const rect = find(targetSelector).getBoundingClientRect();
  const fraction = position === "before" ? 0.25 : 0.75;
  return {
    clientX: rect.left + rect.width / 2,
    clientY: rect.top + rect.height * fraction,
  };
}

function assertDragReady(assert, source, target) {
  assert
    .dom(source)
    .hasAttribute(
      "data-drag-source",
      "",
      "the row is the registered drag source, so it is what a drop receives and what the preview photographs"
    );
  assert
    .dom(`${source} .d-reorderable-list__handle`)
    .hasAttribute(
      "draggable",
      "true",
      "and the handle is where the drag may begin"
    );
  assert
    .dom(target)
    .hasAttribute(
      "data-drop-target",
      "",
      "the destination row is registered for drops"
    );
}

module("Integration | ui-kit | DReorderableList", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the default shell, rows, controls, labels, and row metadata", async function (assert) {
    const items = objectItems();

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{items}}
          @key="identity.value"
          @label={{label}}
          @onMove={{noop}}
        >
          <:row as |item controls|>
            <span
              class="row-content"
              data-test-item={{item.id}}
              data-index={{controls.index}}
              data-first={{if controls.isFirst "true" "false"}}
              data-last={{if controls.isLast "true" "false"}}
              data-movable={{if controls.movable "true" "false"}}
            >{{item.name}}</span>
          </:row>
        </DReorderableList>
      </template>
    );

    assert
      .dom("ul.d-reorderable-list")
      .exists({ count: 1 }, "the default root is one unordered list")
      .doesNotHaveClass(
        "--reveal-controls",
        "controls are always visible by default"
      );
    assert
      .dom(".d-reorderable-list__row")
      .exists(
        { count: items.length },
        "one default list item renders per item"
      );

    for (const [index, item] of items.entries()) {
      const key = item.identity.value;
      const row = rowSelector(key);
      const itemLabel = label(item);

      assert
        .dom(row)
        .hasTagName("li", `the row for ${itemLabel} uses the default item tag`)
        .hasClass(
          "d-reorderable-list__row",
          `the row for ${itemLabel} has the row class`
        );
      assert
        .dom(handleSelector(key))
        .hasTagName("button", `${itemLabel}'s handle is a real control`)
        .hasAria(
          "label",
          `Reorder ${itemLabel}`,
          `${itemLabel}'s handle names the row it moves`
        )
        .hasAttribute(
          "title",
          `Reorder ${itemLabel}`,
          `${itemLabel}'s handle tooltip names the item`
        );
      assert
        .dom(`${row} [data-test-item="${item.id}"]`)
        .hasAttribute(
          "data-index",
          String(index),
          `${itemLabel} yields its visible index`
        )
        .hasAttribute(
          "data-first",
          String(index === 0),
          `${itemLabel} yields its first-movable state`
        )
        .hasAttribute(
          "data-last",
          String(index === items.length - 1),
          `${itemLabel} yields its last-movable state`
        )
        .hasAttribute(
          "data-movable",
          "true",
          `${itemLabel} is movable by default`
        );
    }

    const firstRowChildren = Array.from(
      find(rowSelector(items[0].identity.value)).children
    );
    assert.strictEqual(
      firstRowChildren.length,
      2,
      "a row is its one control plus its content, nothing else"
    );
    assert
      .dom(firstRowChildren[0])
      .hasClass(
        "d-reorderable-list__handle",
        "the control is the first child, before the row block"
      );
    assert.dom(firstRowChildren[1]).hasClass("row-content");
  });

  test("renders the header block before every row", async function (assert) {
    const items = objectItems().slice(0, 2);

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{noop}}
        >
          <:header><li data-slot="header">Header</li></:header>
          <:row as |item|><span
              data-test-item={{item.id}}
            >{{item.name}}</span></:row>
        </DReorderableList>
      </template>
    );

    assert.dom(".d-reorderable-list").exists("the list root renders");
    assert.deepEqual(
      Array.from(find(".d-reorderable-list").children).map(
        (element) => element.dataset.slot ?? element.dataset.reorderableKey
      ),
      ["header", ...items.map((item) => item.id)],
      "the header precedes every row"
    );
  });

  test("renders the empty block in the rows position", async function (assert) {
    const items = [];

    await render(
      <template>
        <DMenus />
        <DReorderableList @items={{items}} @label={{label}} @onMove={{noop}}>
          <:header><li data-slot="header">Header</li></:header>
          <:row as |item|><span data-test-item={{item}}>{{item}}</span></:row>
          <:empty><li data-slot="empty">Nothing here</li></:empty>
        </DReorderableList>
      </template>
    );

    assert.dom(".d-reorderable-list").exists("the empty list root renders");
    assert
      .dom(".d-reorderable-list__row")
      .doesNotExist("an empty collection renders no rows");
    assert.deepEqual(
      Array.from(find(".d-reorderable-list").children).map(
        (element) => element.dataset.slot
      ),
      ["header", "empty"],
      "the empty block replaces the rows after the header"
    );
  });

  test("supports custom shell tags, roles, and attributes", async function (assert) {
    const items = objectItems().slice(0, 1);

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{noop}}
          @tag="section"
          @itemTag="article"
          @role="listbox"
          @itemRole="option"
          id="custom-list"
          class="consumer-list"
          data-consumer="present"
        >
          <:row as |item|>
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </:row>
        </DReorderableList>
      </template>
    );

    assert
      .dom("#custom-list")
      .hasTagName("section", "the root uses the requested tag")
      .hasClass("d-reorderable-list", "the root keeps its base class")
      .hasClass("consumer-list", "the root merges the consumer class")
      .hasAttribute("role", "listbox", "the root receives the requested role")
      .hasAttribute(
        "data-consumer",
        "present",
        "attributes pass through to the root"
      );
    assert
      .dom("#custom-list > .d-reorderable-list__row")
      .hasTagName("article", "rows use the requested item tag")
      .hasAttribute("role", "option", "rows receive the requested item role");
  });

  test("applies string and callback row classes", async function (assert) {
    const items = objectItems().slice(0, 2);
    const seen = new Map();
    const movable = (item) => item.id !== items[1].id;
    const rowClass = (item, row) => {
      seen.set(item.id, { ...row });
      return `row-${row.index} ${row.movable ? "--can-move" : "--fixed"}`;
    };

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{noop}}
          @rowClass="string-one string-two"
          id="string-classes"
        >
          <:row as |item|>
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </:row>
        </DReorderableList>
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{noop}}
          @movable={{movable}}
          @rowClass={{rowClass}}
          id="callback-classes"
        >
          <:row as |item|>
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </:row>
        </DReorderableList>
      </template>
    );

    assert
      .dom("#string-classes > .d-reorderable-list__row")
      .hasClass("string-one", "a string row class is applied")
      .hasClass("string-two", "multiple string classes are preserved");
    assert
      .dom(rowSelector(items[0].id, "#callback-classes"))
      .hasClass("row-0", "the callback receives the first visible index")
      .hasClass("--can-move", "the callback receives the movable state");
    assert
      .dom(rowSelector(items[1].id, "#callback-classes"))
      .hasClass("row-1", "the callback receives the second visible index")
      .hasClass("--fixed", "the callback receives the frozen state");
    assert.deepEqual(
      seen.get(items[1].id),
      { index: 1, movable: false },
      "the callback context contains exactly index and movable"
    );
  });

  test("a manual row places its own handle wherever it belongs", async function (assert) {
    const items = objectItems().slice(0, 1);

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{noop}}
          @controls="manual"
        >
          <:row as |item controls|>
            <span class="row-content" data-test-item={{item.id}}>
              {{item.name}}
            </span>
            <controls.handle />
          </:row>
        </DReorderableList>
      </template>
    );

    const children = Array.from(find(rowSelector(items[0].id)).children);
    assert.strictEqual(children.length, 2);
    assert.dom(children[0]).hasClass("row-content");
    assert
      .dom(children[1])
      .hasClass(
        "d-reorderable-list__handle",
        "a handle placed after the block sits after it in the DOM, so reading and focus order follow the layout"
      );
  });

  test("disabled removes every control and drag registration", async function (assert) {
    const items = objectItems();

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{noop}}
          @disabled={{true}}
        >
          <:row as |item|>
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </:row>
        </DReorderableList>
      </template>
    );

    assert
      .dom(".d-reorderable-list__row")
      .exists({ count: items.length }, "disabled lists still render every row");
    assert
      .dom(".d-reorderable-list__handle")
      .doesNotExist("disabled lists render no handles");
    assert
      .dom(".d-reorderable-list [data-drag-source]")
      .doesNotExist("disabled lists register no drag sources");
    assert
      .dom(".d-reorderable-list [data-drop-target]")
      .doesNotExist("disabled lists register no drop targets");
    assert
      .dom(".d-reorderable-list [draggable]")
      .doesNotExist("disabled lists expose no draggable element");
  });

  test("frozen rows have no controls or drag targets and arrow moves hop over them", async function (assert) {
    const items = objectItems();
    const frozen = items[1];
    const movable = (item) => item !== frozen;
    const moves = [];
    const onMove = (move) => moves.push(move);
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{onMove}}
          @movable={{movable}}
        >
          <:row as |item controls|>
            <span
              data-test-item={{item.id}}
              data-movable={{if controls.movable "true" "false"}}
            >{{item.name}}</span>
          </:row>
        </DReorderableList>
      </template>
    );

    const frozenRow = rowSelector(frozen.id);
    assert
      .dom(`${frozenRow} .d-reorderable-list__handle`)
      .doesNotExist("a frozen row has no handle");
    assert
      .dom(frozenRow)
      .doesNotHaveAttribute("data-drop-target", "a frozen row refuses drops");
    assert
      .dom(`${frozenRow} [data-drag-source]`)
      .doesNotExist("a frozen row is not a drag source");

    await moveVia(items[0].id, "down");

    assert.strictEqual(moves.length, 1, "one chosen move commits once");
    assert.strictEqual(
      moves[0].fromIndex,
      0,
      "the move starts at the first visible index"
    );
    assert.strictEqual(
      moves[0].toIndex,
      2,
      "the move lands at the next movable visible index"
    );
    assert.deepEqual(
      moves[0].proposedToItems,
      [items[2], frozen, items[0]],
      "the movable rows trade places while the frozen row keeps its visible index"
    );
    assert.strictEqual(announce.callCount, 1, "the real hop announces once");

    const source = rowSelector(items[2].id);
    assert
      .dom(source)
      .hasAttribute(
        "data-drag-source",
        "",
        "a movable row remains registered as a drag source"
      );
    assert
      .dom(source)
      .hasAttribute(
        "data-drop-target",
        "",
        "and as a drop target, so a drag between two movable rows is wired"
      );
    await simulateUntargetedDrag(source, frozenRow, {
      dataTransfer: new DataTransfer(),
      targetCoordinates: dropCoordinates(frozenRow, "before"),
    });

    assert.strictEqual(
      moves.length,
      1,
      "dropping on a frozen row commits no move"
    );
    assert.strictEqual(
      announce.callCount,
      1,
      "dropping on a frozen row adds no announcement"
    );
  });

  test("argument changes after the first render are picked up", async function (assert) {
    // Every one of these is read lazily today. A collaborator that captured
    // one at construction would still pass every other test in this file,
    // because nothing else swaps an argument after the first render.
    const items = trackedArray(objectItems());
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
    const state = new (class {
      @tracked movable = () => true;
      @tracked removable = () => true;
      @tracked itemLabel = label;
    })();

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{state.itemLabel}}
          @movable={{state.movable}}
          @removable={{state.removable}}
          @onMove={{noop}}
          @onRemove={{noop}}
        >
          <:row as |item|>
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </:row>
        </DReorderableList>
      </template>
    );

    assert.dom(".d-reorderable-list__handle").exists({ count: 3 });
    assert.dom(".d-reorderable-list__remove").exists({ count: 3 });

    state.movable = (item) => item.id !== "bravo";
    await settled();
    assert
      .dom(handleSelector("bravo"))
      .doesNotExist("a swapped @movable re-freezes the row");
    assert.dom(".d-reorderable-list__handle").exists({ count: 2 });

    state.removable = (item) => item.id !== "charlie";
    await settled();
    assert
      .dom(`${rowSelector("charlie")} .d-reorderable-list__remove`)
      .doesNotExist("a swapped @removable withdraws the control");

    state.itemLabel = (item) => `Renamed ${item.name}`;
    await settled();
    await moveVia("alpha", "down");
    assert.true(
      announce.lastCall.args[0].includes("Renamed Alpha"),
      "the announcement reads through the swapped @label rather than a captured one"
    );
  });

  test("disables only the boundary directions in the movable subsequence", async function (assert) {
    const items = objectItems();
    const movable = (item) => item !== items[1];

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{noop}}
          @movable={{movable}}
        >
          <:row as |item|>
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </:row>
        </DReorderableList>
      </template>
    );

    await openMoveMenu(items[0].id);
    assert
      .dom(moveItemSelector("up"))
      .isDisabled("the first movable item cannot move up");
    assert
      .dom(moveItemSelector("down"))
      .isNotDisabled("the first movable item can move down");
    await click(moveItemSelector("down"));

    await openMoveMenu(items[2].id);
    assert
      .dom(moveItemSelector("up"))
      .isNotDisabled("the last movable item can move up");
    assert
      .dom(moveItemSelector("down"))
      .isDisabled("the last movable item cannot move down");
  });

  test("disables both arrows for a single movable item", async function (assert) {
    const items = objectItems().slice(0, 1);

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{noop}}
        >
          <:row as |item|>
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </:row>
        </DReorderableList>
      </template>
    );

    await openMoveMenu(items[0].id);
    for (const target of ["top", "up", "down", "bottom"]) {
      assert
        .dom(moveItemSelector(target))
        .isDisabled(`the sole movable item cannot move ${target}`);
    }
  });

  test("menu moves emit the exact move payload and one default announcement", async function (assert) {
    const items = objectItems();
    const moves = [];
    const onMove = (move) => moves.push(move);
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{items}}
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

    await moveVia(items[1].id, "up");

    const proposed = [items[1], items[0], items[2]];
    assert.strictEqual(
      moves.length,
      1,
      "one menu choice calls onMove exactly once"
    );
    assert.deepEqual(
      moves[0],
      {
        method: "menu",
        item: items[1],
        fromList: "default",
        toList: "default",
        fromIndex: 1,
        toIndex: 0,
        fromItems: items,
        toItems: items,
        proposedFromItems: proposed,
        proposedToItems: proposed,
      },
      "the button path emits only the complete public move shape"
    );
    assert.strictEqual(
      moves[0].fromItems,
      moves[0].toItems,
      "single-list source arrays share one reference"
    );
    assert.strictEqual(
      moves[0].proposedFromItems,
      moves[0].proposedToItems,
      "single-list proposed arrays share one reference"
    );
    assert.strictEqual(
      announce.callCount,
      1,
      "the real move announces exactly once"
    );
    assert.strictEqual(
      announce.firstCall.args[0],
      `Moved ${label(items[1])} to position ${moves[0].toIndex + 1} of ${proposed.length}`,
      "the default announcement names the item and its measured destination"
    );
  });

  test("a trackedArray host reorders once, rerenders, announces once, and retains focus", async function (assert) {
    const sourceItems = objectItems();
    const items = trackedArray(sourceItems);
    let moveCount = 0;
    const onMove = (move) => {
      moveCount++;
      items.splice(0, items.length, ...move.proposedToItems);
    };
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{items}}
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

    await moveVia(sourceItems[1].id, "down");

    const expectedOrder = [sourceItems[0], sourceItems[2], sourceItems[1]];
    assert.strictEqual(
      moveCount,
      1,
      "the tracked host receives one callback without re-entry"
    );
    assert.deepEqual(
      Array.from(items),
      expectedOrder,
      "the host adopts the proposed order"
    );
    assert.deepEqual(
      renderedItemOrder(),
      expectedOrder.map((item) => item.id),
      "the component rerenders the tracked array in its new order"
    );
    assert.strictEqual(
      announce.callCount,
      1,
      "the host-driven rerender does not double-announce"
    );
    assert
      .dom(handleSelector(sourceItems[1].id))
      .isFocused("the handle regains focus after its keyed row moves");
  });

  test("an onMove false return vetoes the announcement", async function (assert) {
    const items = objectItems();
    const onMove = sinon.stub().returns(false);
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{items}}
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

    await moveVia(items[1].id, "up");

    assert.strictEqual(
      onMove.callCount,
      1,
      "the vetoing callback still receives the move"
    );
    assert.strictEqual(announce.callCount, 0, "a vetoed move is not announced");
  });

  test("announceMove overrides the default announcement", async function (assert) {
    const items = objectItems();
    let announcedMove;
    let committedMove;
    const onMove = (move) => (committedMove = move);
    const customMessage = `Custom move for ${label(items[1])}`;
    const announceMove = (move) => {
      announcedMove = move;
      return customMessage;
    };
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{onMove}}
          @announceMove={{announceMove}}
        >
          <:row as |item|>
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </:row>
        </DReorderableList>
      </template>
    );

    await moveVia(items[1].id, "up");

    assert.strictEqual(
      announcedMove,
      committedMove,
      "the override receives the committed move object"
    );
    assert.strictEqual(
      announce.callCount,
      1,
      "the override still produces one announcement"
    );
    assert.strictEqual(
      announce.firstCall.args[0],
      customMessage,
      "the override supplies the spoken text"
    );
  });

  test("announceMove false suppresses only the announcement", async function (assert) {
    const items = objectItems();
    const onMove = sinon.spy();
    const announceMove = sinon.stub().returns(false);
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{onMove}}
          @announceMove={{announceMove}}
        >
          <:row as |item|>
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </:row>
        </DReorderableList>
      </template>
    );

    await moveVia(items[1].id, "up");

    assert.strictEqual(
      onMove.callCount,
      1,
      "onMove still receives the real move"
    );
    assert.strictEqual(
      announceMove.callCount,
      1,
      "the announcement override evaluates once"
    );
    assert.strictEqual(
      announce.callCount,
      0,
      "false suppresses the a11y service call"
    );
  });

  test("a before drop emits the exact drag payload and one announcement", async function (assert) {
    const items = objectItems();
    const moves = [];
    const onMove = (move) => moves.push(move);
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{items}}
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

    const source = rowSelector(items[0].id);
    const target = rowSelector(items[2].id);
    assertDragReady(assert, source, target);
    await simulateDrag(source, target, {
      dataTransfer: new DataTransfer(),
      targetCoordinates: dropCoordinates(target, "before"),
    });

    const proposed = [items[1], items[0], items[2]];
    assert.strictEqual(
      moves.length,
      1,
      "one before drop calls onMove exactly once"
    );
    assert.deepEqual(
      moves[0],
      {
        method: "drag",
        item: items[0],
        fromList: "default",
        toList: "default",
        fromIndex: 0,
        toIndex: 1,
        fromItems: items,
        toItems: items,
        proposedFromItems: proposed,
        proposedToItems: proposed,
      },
      "the drag path emits only the complete public move shape"
    );
    assert.strictEqual(
      moves[0].fromItems,
      moves[0].toItems,
      "single-list drag arrays share one reference"
    );
    assert.strictEqual(
      moves[0].proposedFromItems,
      moves[0].proposedToItems,
      "single-list proposed drag arrays share one reference"
    );
    assert.strictEqual(
      announce.callCount,
      1,
      "the real drop announces exactly once"
    );
    assert.strictEqual(
      announce.firstCall.args[0],
      `Moved ${label(items[0])} to position ${moves[0].toIndex + 1} of ${proposed.length}`,
      "the drag announcement uses the normalized destination"
    );
  });

  test("an after drop normalizes to the post-removal destination", async function (assert) {
    const items = objectItems();
    const moves = [];
    const onMove = (move) => moves.push(move);

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{items}}
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

    const source = rowSelector(items[2].id);
    const target = rowSelector(items[0].id);
    assertDragReady(assert, source, target);
    await simulateDrag(source, target, {
      dataTransfer: new DataTransfer(),
      targetCoordinates: dropCoordinates(target, "after"),
    });

    assert.strictEqual(moves.length, 1, "one after drop commits once");
    assert.deepEqual(
      {
        fromIndex: moves[0].fromIndex,
        toIndex: moves[0].toIndex,
        proposed: moves[0].proposedToItems,
      },
      { fromIndex: 2, toIndex: 1, proposed: [items[0], items[2], items[1]] },
      "after means target index plus one before removal normalization"
    );
  });

  test("a same-index drop is a no-op", async function (assert) {
    const items = objectItems();
    const onMove = sinon.spy();
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{items}}
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

    const source = rowSelector(items[0].id);
    const target = rowSelector(items[1].id);
    assertDragReady(assert, source, target);
    await simulateDrag(source, target, {
      dataTransfer: new DataTransfer(),
      targetCoordinates: dropCoordinates(target, "before"),
    });

    assert.strictEqual(
      onMove.callCount,
      0,
      "a normalized same-index drop does not call onMove"
    );
    assert.strictEqual(
      announce.callCount,
      0,
      "a normalized same-index drop is not announced"
    );
  });

  test("drag keys resolve the current item and indices at drop time", async function (assert) {
    const initialItems = objectItems();
    const currentItems = [
      { ...initialItems[2], name: `${initialItems[2].name} current` },
      { ...initialItems[0], name: `${initialItems[0].name} current` },
      { ...initialItems[1], name: `${initialItems[1].name} current` },
    ];
    const state = new (class {
      @tracked items = initialItems;
    })();
    const moves = [];
    const onMove = (move) => moves.push(move);

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{state.items}}
          @key="id"
          @label={{label}}
          @onMove={{onMove}}
        >
          <:row as |item|><span
              data-test-item={{item.id}}
            >{{item.name}}</span></:row>
        </DReorderableList>
      </template>
    );

    const draggedKey = initialItems[1].id;
    const sourceHandle = `${rowSelector(draggedKey)} .d-reorderable-list__handle`;
    const dataTransfer = new DataTransfer();
    assert
      .dom(rowSelector(draggedKey))
      .hasAttribute(
        "data-drag-source",
        "",
        "the keyed source handle is registered before the drag starts"
      );
    await dragEvent(sourceHandle, "dragstart", {
      dataTransfer,
      ...centerOf(sourceHandle),
    });
    assert
      .dom(rowSelector(draggedKey))
      .hasClass(
        "--dragging",
        "the primitive marks the dragged row, so no state is mirrored by hand"
      );

    state.items = currentItems;
    await settled();

    const target = rowSelector(initialItems[0].id);
    assert
      .dom(target)
      .hasAttribute(
        "data-drop-target",
        "",
        "the current target row remains registered after the host rerenders"
      );
    const targetCoordinates = dropCoordinates(target, "before");
    await dragEvent(target, "dragenter", {
      dataTransfer,
      ...targetCoordinates,
    });
    await dragEvent(target, "dragover", { dataTransfer, ...targetCoordinates });
    await dragEvent(target, "drop", { dataTransfer, ...targetCoordinates });

    const currentSourceHandle = `${rowSelector(draggedKey)} .d-reorderable-list__handle`;
    await dragEvent(currentSourceHandle, "dragend", {
      dataTransfer,
      ...centerOf(currentSourceHandle),
    });
    assert
      .dom(rowSelector(draggedKey))
      .doesNotHaveClass(
        "--dragging",
        "the source clears its drag state at the end"
      );

    assert.strictEqual(
      moves.length,
      1,
      "the in-flight drag commits once after the host changes"
    );
    assert.strictEqual(
      moves[0].item,
      currentItems[2],
      "the key resolves to the replacement item object"
    );
    assert.strictEqual(
      moves[0].fromItems,
      currentItems,
      "the payload uses the current visible array"
    );
    assert.deepEqual(
      {
        fromIndex: moves[0].fromIndex,
        toIndex: moves[0].toIndex,
        proposed: moves[0].proposedToItems,
      },
      {
        fromIndex: 2,
        toIndex: 1,
        proposed: [currentItems[0], currentItems[2], currentItems[1]],
      },
      "indices and proposed order resolve against the current items at drop time"
    );
  });

  test("separate instances reject each other's drags", async function (assert) {
    const firstItems = objectItems().slice(0, 2);
    const secondItems = objectItems().slice(1);
    const firstOnMove = sinon.spy();
    const secondOnMove = sinon.spy();
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{firstItems}}
          @key="id"
          @label={{label}}
          @onMove={{firstOnMove}}
          id="first-list"
        >
          <:row as |item|>
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </:row>
        </DReorderableList>
        <DReorderableList
          @items={{secondItems}}
          @key="id"
          @label={{label}}
          @onMove={{secondOnMove}}
          id="second-list"
        >
          <:row as |item|>
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </:row>
        </DReorderableList>
      </template>
    );

    const source = rowSelector(firstItems[0].id, "#first-list");
    const target = rowSelector(secondItems[1].id, "#second-list");
    assertDragReady(assert, source, target);
    await simulateDrag(source, target, {
      dataTransfer: new DataTransfer(),
      targetCoordinates: dropCoordinates(target, "before"),
    });

    assert.strictEqual(
      firstOnMove.callCount,
      0,
      "the source instance does not receive a cross-list move"
    );
    assert.strictEqual(
      secondOnMove.callCount,
      0,
      "the target instance rejects the foreign drag type"
    );
    assert.strictEqual(
      announce.callCount,
      0,
      "a rejected cross-instance drag is not announced"
    );
  });

  test("rejects duplicate resolved keys", async function (assert) {
    const items = objectItems();
    items[1].id = items[0].id;
    let raised;

    setupOnerror((error) => {
      raised = error;
    });

    try {
      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
          >
            <:row as |item|>
              <span data-test-item={{item.name}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );
    } finally {
      resetOnerror();
    }

    assert.true(
      /duplicate|unique|key/i.test(raised?.message ?? ""),
      "duplicate resolved keys trigger a development assertion"
    );
  });

  test("supports @index identity for primitive collections", async function (assert) {
    const items = ["Alpha", "Bravo", "Charlie"];
    const indexKey = "@index";

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{items}}
          @key={{indexKey}}
          @label={{label}}
          @onMove={{noop}}
        >
          <:row as |item|>
            <span data-test-item={{item}}>{{item}}</span>
          </:row>
        </DReorderableList>
      </template>
    );

    assert.deepEqual(
      findAll(".d-reorderable-list__row").map(
        (element) => element.dataset.reorderableKey
      ),
      items.map((_, index) => String(index)),
      "@index resolves primitive row identities from their visible indices"
    );
    assert.deepEqual(
      renderedItemOrder(),
      items,
      "primitive row content stays in display order"
    );
  });

  test("uses object identity for keyed rerendering when key is omitted", async function (assert) {
    const items = objectItems();
    const state = new (class {
      @tracked items = items;
    })();

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{state.items}}
          @label={{label}}
          @onMove={{noop}}
        >
          <:row as |item|>
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </:row>
        </DReorderableList>
      </template>
    );

    assert
      .dom(".d-reorderable-list__row")
      .exists(
        { count: items.length },
        "every object renders a row before identity is inspected"
      );
    const keys = findAll(".d-reorderable-list__row").map(
      (element) => element.dataset.reorderableKey
    );
    const firstRow = find("[data-test-item='alpha']").closest(
      ".d-reorderable-list__row"
    );

    assert.true(
      keys.every(Boolean),
      "object identity produces a DOM key for every row"
    );
    assert.strictEqual(
      new Set(keys).size,
      items.length,
      "distinct objects resolve distinct DOM keys"
    );

    state.items = [...items].reverse();
    await settled();

    assert.deepEqual(
      renderedItemOrder(),
      [...items].reverse().map((item) => item.id),
      "the rows follow the reordered object collection"
    );
    assert.strictEqual(
      find("[data-test-item='alpha']").closest(".d-reorderable-list__row"),
      firstRow,
      "the row element follows its object identity across the rerender"
    );
  });
});

module(
  "Integration | ui-kit | DReorderableList | manual controls and create",
  function (hooks) {
    setupRenderingTest(hooks);

    test("manual mode renders no automatic controls", async function (assert) {
      const items = objectItems();

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @controls="manual"
          >
            <:row as |item controls|>
              <span class="row-content" data-test-item={{item.id}}>
                {{item.name}}
              </span>
              {{#if controls.handle}}
                <div class="consumer-control-cell"><controls.handle /></div>
              {{/if}}
            </:row>
          </DReorderableList>
        </template>
      );

      assert
        .dom(".d-reorderable-list__row > .d-reorderable-list__handle")
        .doesNotExist("manual mode inserts no handle beside the row block");
      assert
        .dom(".row-content")
        .exists(
          { count: items.length },
          "every row block still renders when controls are manual"
        );
    });

    test("manual row API exposes controls only for movable manual rows", async function (assert) {
      const items = objectItems().slice(0, 2);
      const movable = (item) => item === items[0];

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @controls="manual"
            @movable={{movable}}
            id="manual-api"
          >
            <:row as |item controls|>
              <span
                data-test-item={{item.id}}
                data-handle={{if controls.handle "true" "false"}}
              >{{item.name}}</span>
              {{#if controls.handle}}<controls.handle />{{/if}}
            </:row>
          </DReorderableList>

          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            id="auto-api"
          >
            <:row as |item controls|><span
                data-test-item={{item.id}}
                data-handle={{if controls.handle "true" "false"}}
              >{{item.name}}</span></:row>
          </DReorderableList>
        </template>
      );

      assert
        .dom(`${rowSelector(items[0].id, "#manual-api")} [data-test-item]`)
        .hasAttribute(
          "data-handle",
          "true",
          "a movable manual row yields a handle"
        );
      assert
        .dom(`${rowSelector(items[1].id, "#manual-api")} [data-test-item]`)
        .hasAttribute(
          "data-handle",
          "false",
          "a frozen manual row yields no handle"
        );

      for (const root of ["#auto-api"]) {
        assert
          .dom(`${root} [data-test-item]`)
          .hasAttribute(
            "data-handle",
            "false",
            `${root} rows do not yield a manual handle`
          );
      }
    });

    test("a manually placed handle matches the automatic one", async function (assert) {
      const items = objectItems();

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @controls="manual"
          >
            <:row as |item controls|>
              <div class="consumer-cell" data-test-item={{item.id}}>
                <controls.handle
                  class="consumer-handle"
                  data-consumer-handle={{item.id}}
                />
              </div>
            </:row>
          </DReorderableList>
        </template>
      );

      assert
        .dom(".consumer-cell > .d-reorderable-list__handle")
        .exists(
          { count: items.length },
          "one manually placed handle renders inside each nested cell"
        );

      for (const [index, item] of items.entries()) {
        const row = rowSelector(item.id);
        const itemLabel = label(item);

        assert
          .dom(`${row} .consumer-handle`)
          .hasTagName(
            "button",
            `${itemLabel}'s manual handle is a real control`
          )
          .hasClass(
            "d-reorderable-list__handle",
            `${itemLabel}'s manual handle keeps the list class`
          )
          .hasAria(
            "label",
            `Reorder ${itemLabel}`,
            `${itemLabel}'s manual handle uses the standard translated label`
          )
          .hasAttribute(
            "data-consumer-handle",
            item.id,
            `${itemLabel}'s consumer attribute passes through`
          )
          .hasAttribute(
            "draggable",
            "true",
            `${itemLabel}'s manual handle is still where a drag begins`
          );

        await openMoveMenu(item.id);

        const expectDisabled = {
          up: index === 0,
          down: index === items.length - 1,
        };
        for (const [target, disabled] of Object.entries(expectDisabled)) {
          if (disabled) {
            assert
              .dom(moveItemSelector(target))
              .isDisabled(
                `${itemLabel}'s manual menu marks ${target} at the boundary`
              );
          } else {
            assert
              .dom(moveItemSelector(target))
              .isNotDisabled(
                `${itemLabel}'s manual menu leaves ${target} available`
              );
          }
        }

        await triggerKeyEvent(document.activeElement, "keydown", "Escape");
      }
    });

    test("manually placed handle commits a normalized drag move", async function (assert) {
      const items = objectItems();
      const sourceItem = items[0];
      const targetItem = items.at(-1);
      const fromIndex = items.indexOf(sourceItem);
      const targetIndex = items.indexOf(targetItem);
      const toIndex = targetIndex - Number(fromIndex < targetIndex);
      const proposed = [...items];
      proposed.splice(fromIndex, 1);
      proposed.splice(toIndex, 0, sourceItem);
      const moves = [];
      const onMove = (move) => moves.push(move);

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{onMove}}
            @controls="manual"
          >
            <:row as |item controls|>
              <div data-test-item={{item.id}}>
                <span class="consumer-handle-cell"><controls.handle /></span>
              </div>
            </:row>
          </DReorderableList>
        </template>
      );

      const source = rowSelector(sourceItem.id);
      const target = rowSelector(targetItem.id);
      await simulateDrag(source, target, {
        dataTransfer: new DataTransfer(),
        targetCoordinates: dropCoordinates(target, "before"),
      });

      assert.strictEqual(
        moves.length,
        1,
        "one manual-handle drag commits once"
      );
      assert.deepEqual(
        moves[0],
        {
          method: "drag",
          item: sourceItem,
          fromList: "default",
          toList: "default",
          fromIndex,
          toIndex,
          fromItems: items,
          toItems: items,
          proposedFromItems: proposed,
          proposedToItems: proposed,
        },
        "the nested manual handle emits the complete normalized drag payload"
      );
    });

    test("a handle-only manual surface commits and announces without asserting", async function (assert) {
      const items = objectItems();
      const movedItem = items[1];
      const fromIndex = items.indexOf(movedItem);
      const toIndex = fromIndex - 1;
      const proposed = [...items];
      proposed.splice(fromIndex, 1);
      proposed.splice(toIndex, 0, movedItem);
      const moves = [];
      const onMove = (move) => moves.push(move);
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
      let raised;

      setupOnerror((error) => {
        raised = error;
      });

      try {
        await render(
          <template>
            <DMenus />
            <DReorderableList
              @items={{items}}
              @key="id"
              @label={{label}}
              @onMove={{onMove}}
              @controls="manual"
            >
              <:row as |item controls|>
                <div data-test-item={{item.id}}><controls.handle /></div>
              </:row>
            </DReorderableList>
          </template>
        );

        await moveVia(movedItem.id, "up");
      } finally {
        resetOnerror();
      }

      assert.strictEqual(
        raised,
        undefined,
        "the placed handle satisfies the manual guard"
      );
      assert
        .dom(".d-reorderable-list__handle")
        .exists(
          { count: items.length },
          "the handle a manual row places is its only control"
        );
      assert.strictEqual(
        moves.length,
        1,
        "one manual menu choice commits once"
      );
      assert.deepEqual(
        moves[0],
        {
          method: "menu",
          item: movedItem,
          fromList: "default",
          toList: "default",
          fromIndex,
          toIndex,
          fromItems: items,
          toItems: items,
          proposedFromItems: proposed,
          proposedToItems: proposed,
        },
        "manual arrows emit the complete normalized button payload"
      );
      assert.strictEqual(
        announce.callCount,
        1,
        "the manual arrow move announces once"
      );
      assert.strictEqual(
        announce.firstCall.args[0],
        `Moved ${label(movedItem)} to position ${moves[0].toIndex + 1} of ${proposed.length}`,
        "manual arrows use the standard measured announcement"
      );
    });

    test("manual mode asserts when a movable row omits its handle", async function (assert) {
      const items = objectItems().slice(0, 1);
      let raised;

      setupOnerror((error) => {
        raised = error;
      });

      try {
        await render(
          <template>
            <DMenus />
            <DReorderableList
              @items={{items}}
              @key="id"
              @label={{label}}
              @onMove={{noop}}
              @controls="manual"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </template>
        );
      } finally {
        resetOnerror();
      }

      assert
        .dom("[data-test-item]")
        .exists("the manual row renders before the delayed guard runs");
      assert.true(
        /Assertion Failed:.*handle/i.test(raised?.message ?? ""),
        "a movable row with no handle has no way to reorder, and says so"
      );
    });

    test("allowCreate renders the default create row between rows and static content", async function (assert) {
      const items = objectItems().slice(0, 2);
      const accessibleName = await loadAccessibleName();

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @onCreate={{noop}}
            @allowCreate={{true}}
          >
            <:row as |item|><span
                data-test-item={{item.id}}
              >{{item.name}}</span></:row>
          </DReorderableList>
        </template>
      );

      assert.deepEqual(
        Array.from(find(".d-reorderable-list").children).map((element) => {
          if (element.classList.contains("d-reorderable-list__create")) {
            return "create";
          }
          return element.dataset.reorderableKey ?? element.dataset.slot;
        }),
        [...items.map((item) => item.id), "create"],
        "the create row follows every item and precedes static content"
      );
      assert
        .dom(".d-reorderable-list__create")
        .exists({ count: 1 }, "one default create row renders");
      assert
        .dom(".d-reorderable-list__create-input")
        .hasTagName("input", "the default create control is an input");
      assert.strictEqual(
        find(".d-reorderable-list__create-input").type,
        "text",
        "the create input accepts text"
      );
      assert.strictEqual(
        accessibleName(find(".d-reorderable-list__create-input")),
        "Add an item",
        "the create input has the translated accessible name"
      );
      assert
        .dom(".d-reorderable-list__create button")
        .exists({ count: 1 }, "the create row has one icon button");
      assert.strictEqual(
        accessibleName(find(".d-reorderable-list__create button")),
        "Add an item",
        "the create button has the translated accessible name"
      );
      assert
        .dom(".d-reorderable-list__create button .d-icon")
        .exists("the create action is rendered as an icon button");
    });

    test("Enter creates one trimmed value and clears the input while ignoring whitespace", async function (assert) {
      const items = objectItems().slice(0, 1);
      const onCreate = sinon.spy();
      const enteredValue = `  ${items[0].name} draft  `;
      const expectedValue = enteredValue.trim();

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @onCreate={{onCreate}}
            @allowCreate={{true}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      const input = ".d-reorderable-list__create-input";
      await fillIn(input, enteredValue);
      await triggerKeyEvent(input, "keydown", "Enter");

      assert.strictEqual(
        onCreate.callCount,
        1,
        "Enter calls onCreate exactly once"
      );
      assert.strictEqual(
        onCreate.firstCall.args[0],
        expectedValue,
        "Enter submits the measured trimmed value"
      );
      assert
        .dom(input)
        .hasValue("", "a successful Enter submission clears the input");

      await fillIn(input, "   ");
      await triggerKeyEvent(input, "keydown", "Enter");

      assert.strictEqual(
        onCreate.callCount,
        1,
        "Enter on whitespace adds no create callback"
      );
    });

    test("create button submits one trimmed value and clears the input while ignoring whitespace", async function (assert) {
      const items = objectItems().slice(0, 1);
      const onCreate = sinon.spy();
      const enteredValue = `  ${items[0].id} copy  `;
      const expectedValue = enteredValue.trim();

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @onCreate={{onCreate}}
            @allowCreate={{true}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      const input = ".d-reorderable-list__create-input";
      const button = ".d-reorderable-list__create button";
      await fillIn(input, enteredValue);
      await click(button);

      assert.strictEqual(
        onCreate.callCount,
        1,
        "the create button calls onCreate exactly once"
      );
      assert.strictEqual(
        onCreate.firstCall.args[0],
        expectedValue,
        "the create button submits the measured trimmed value"
      );
      assert
        .dom(input)
        .hasValue("", "a successful button submission clears the input");

      await fillIn(input, "\t  ");
      await click(button);

      assert.strictEqual(
        onCreate.callCount,
        1,
        "clicking create for whitespace adds no callback"
      );
    });

    test("create UI is absent unless allowCreate is true", async function (assert) {
      const items = objectItems().slice(0, 1);

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @onCreate={{noop}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      assert
        .dom(".d-reorderable-list__create")
        .doesNotExist("the create row is opt-in");
      assert
        .dom(".d-reorderable-list__create-input")
        .doesNotExist("an opted-out list has no create input");
    });

    test("custom create block replaces the default create row", async function (assert) {
      const items = objectItems().slice(0, 1);

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @onCreate={{noop}}
            @allowCreate={{true}}
          >
            <:row as |item|><span
                data-test-item={{item.id}}
              >{{item.name}}</span></:row>
            <:create><li data-slot="create">Consumer create</li></:create>
          </DReorderableList>
        </template>
      );

      assert.deepEqual(
        Array.from(find(".d-reorderable-list").children).map(
          (element) => element.dataset.reorderableKey ?? element.dataset.slot
        ),
        [items[0].id, "create"],
        "the custom create block occupies the default create position"
      );
      assert
        .dom("[data-slot='create']")
        .exists({ count: 1 }, "the consumer create block renders once");
      assert
        .dom(".d-reorderable-list__create")
        .doesNotExist(
          "the custom block replaces the default create row entirely"
        );
      assert
        .dom(".d-reorderable-list__create-input")
        .doesNotExist("the custom block renders no default input");
    });

    test("create renders alongside the empty block", async function (assert) {
      const items = [];

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @label={{label}}
            @onMove={{noop}}
            @onCreate={{noop}}
            @allowCreate={{true}}
          >
            <:row as |item|><span data-test-item={{item}}>{{item}}</span></:row>
            <:empty><li data-slot="empty">Nothing here</li></:empty>
          </DReorderableList>
        </template>
      );

      assert.deepEqual(
        Array.from(find(".d-reorderable-list").children).map((element) => {
          if (element.classList.contains("d-reorderable-list__create")) {
            return "create";
          }
          return element.dataset.slot;
        }),
        ["empty", "create"],
        "the empty block and create row both render before static content"
      );
      assert
        .dom(".d-reorderable-list__create-input")
        .exists("an empty collection still offers the create input");
    });

    test("removing a dragged item clears its state before reinsertion", async function (assert) {
      const initialItems = objectItems();
      const draggedItem = initialItems[1];
      const state = new (class {
        @tracked items = initialItems;
      })();

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{state.items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
          >
            <:row as |item|><span
                data-test-item={{item.id}}
              >{{item.name}}</span></:row>
          </DReorderableList>
        </template>
      );

      const sourceHandle = `${rowSelector(draggedItem.id)} .d-reorderable-list__handle`;
      const sourceElement = find(sourceHandle);
      const sourceCoordinates = centerOf(sourceHandle);
      const dataTransfer = new DataTransfer();
      await dragEvent(sourceElement, "dragstart", {
        dataTransfer,
        ...sourceCoordinates,
      });
      assert
        .dom(rowSelector(draggedItem.id))
        .hasClass(
          "--dragging",
          "the primitive marks the dragged row, so no state is mirrored by hand"
        );

      state.items = initialItems.filter((item) => item !== draggedItem);
      await settled();
      assert
        .dom(rowSelector(draggedItem.id))
        .doesNotExist("the host removes the in-flight row");

      await dragEvent(sourceElement, "dragend", {
        dataTransfer,
        ...sourceCoordinates,
      });
      state.items = initialItems;
      await settled();

      assert
        .dom(rowSelector(draggedItem.id))
        .doesNotHaveClass(
          "--dragging",
          "a reinserted row does not inherit a removed drag's state"
        );
    });
  }
);

module("Integration | ui-kit | DReorderableList | group", function (hooks) {
  setupRenderingTest(hooks);

  test("DReorderableListGroup renders no wrapper around its block", async function (assert) {
    await render(
      <template>
        <DMenus />
        <div id="group-placement">
          <span data-placement="before">Before</span>
          <DReorderableListGroup @onMove={{noop}} as |group|>
            <span
              data-placement="first"
              data-group-context={{if group "present" "missing"}}
            >First</span>
            <span data-placement="last">Last</span>
          </DReorderableListGroup>
          <span data-placement="after">After</span>
        </div>
      </template>
    );

    assert.deepEqual(
      Array.from(find("#group-placement").children).map(
        (element) => element.dataset.placement
      ),
      ["before", "first", "last", "after"],
      "the group inserts no element between its parent and block content"
    );
  });

  test("a group onMove false return vetoes the announcement", async function (assert) {
    const items = trackedArray(objectItems());
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
    const moves = [];
    // The group's callback wins over any member's own, so this is the veto the
    // member never sees.
    const groupMove = (move) => {
      moves.push(move);
      return false;
    };

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{groupMove}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="primary"
            @listLabel="Primary"
            @items={{items}}
            @key="id"
            @label={{label}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    await moveVia("alpha", "down");

    assert.strictEqual(moves.length, 1, "the group callback still receives it");
    assert.strictEqual(
      announce.callCount,
      0,
      "a move the group vetoed is not announced"
    );
  });

  test("DReorderableList requires listId when it joins a group", async function (assert) {
    const items = objectItems().slice(0, 1);
    let raised;

    setupOnerror((error) => {
      raised = error;
    });

    try {
      await render(
        <template>
          <DMenus />
          <DReorderableListGroup @onMove={{noop}} as |group|>
            <DReorderableList
              @group={{group}}
              @items={{items}}
              @key="id"
              @label={{label}}
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );
    } finally {
      resetOnerror();
    }

    assert.true(
      /Assertion Failed:.*(list.?id|required|group)/i.test(
        raised?.message ?? ""
      ),
      "a grouped member without listId triggers a development assertion"
    );
  });

  test("DReorderableList routes an in-list menu move through the group", async function (assert) {
    const primaryItems = objectItems();
    const secondaryItems = [{ id: "secondary-alpha", name: "Secondary Alpha" }];
    const movedItem = primaryItems[1];
    const fromIndex = primaryItems.indexOf(movedItem);
    const toIndex = fromIndex - 1;
    const proposed = [...primaryItems];
    proposed.splice(fromIndex, 1);
    proposed.splice(toIndex, 0, movedItem);
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
              @listId="primary"
              @listLabel="Primary links"
              @items={{primaryItems}}
              @key="id"
              @label={{label}}
              id="button-primary-list"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
            <DReorderableList
              @group={{group}}
              @listId="secondary"
              @items={{secondaryItems}}
              @key="id"
              @label={{label}}
              id="button-secondary-list"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );

      await moveVia(movedItem.id, "up", "#button-primary-list");
    } finally {
      resetOnerror();
    }

    assert.strictEqual(
      raised,
      undefined,
      "the grouped menu move raises no error"
    );

    assert.strictEqual(
      onMove.callCount,
      1,
      "one member menu move calls the group callback exactly once"
    );
    assert.deepEqual(
      onMove.firstCall.args[0],
      {
        method: "menu",
        item: movedItem,
        fromList: "primary",
        toList: "primary",
        fromIndex,
        toIndex,
        fromItems: primaryItems,
        toItems: primaryItems,
        proposedFromItems: proposed,
        proposedToItems: proposed,
      },
      "the grouped menu path keeps the standalone payload shape with member IDs"
    );
    assert.strictEqual(
      onMove.firstCall.args[0].fromItems,
      primaryItems,
      "the button payload carries the live member items reference"
    );
    assert.strictEqual(
      onMove.firstCall.args[0].proposedFromItems,
      onMove.firstCall.args[0].proposedToItems,
      "an in-list grouped button move shares one proposed array"
    );
    assert.strictEqual(
      announce.callCount,
      1,
      "the grouped button move announces exactly once"
    );
    assert.strictEqual(
      announce.firstCall.args[0],
      `Moved ${label(movedItem)} to position ${toIndex + 1} of ${proposed.length}`,
      "an in-list grouped button move uses the standard announcement"
    );
  });

  test("DReorderableList routes an in-list drag move through the group", async function (assert) {
    const primaryItems = objectItems();
    const secondaryItems = [{ id: "secondary-alpha", name: "Secondary Alpha" }];
    const movedItem = primaryItems[2];
    const targetItem = primaryItems[0];
    const fromIndex = primaryItems.indexOf(movedItem);
    const targetIndex = primaryItems.indexOf(targetItem);
    const toIndex = targetIndex + 1;
    const proposed = [...primaryItems];
    proposed.splice(fromIndex, 1);
    proposed.splice(toIndex, 0, movedItem);
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
              @listId="primary"
              @items={{primaryItems}}
              @key="id"
              @label={{label}}
              id="drag-primary-list"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
            <DReorderableList
              @group={{group}}
              @listId="secondary"
              @items={{secondaryItems}}
              @key="id"
              @label={{label}}
              id="drag-secondary-list"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );

      const source = rowSelector(movedItem.id, "#drag-primary-list");
      const target = rowSelector(targetItem.id, "#drag-primary-list");
      assertDragReady(assert, source, target);
      await simulateDrag(source, target, {
        dataTransfer: new DataTransfer(),
        targetCoordinates: dropCoordinates(target, "after"),
      });
    } finally {
      resetOnerror();
    }

    assert.strictEqual(
      raised,
      undefined,
      "the grouped drag move raises no error"
    );

    assert.strictEqual(
      onMove.callCount,
      1,
      "one member drag calls the group callback exactly once"
    );
    assert.deepEqual(
      onMove.firstCall.args[0],
      {
        method: "drag",
        item: movedItem,
        fromList: "primary",
        toList: "primary",
        fromIndex,
        toIndex,
        fromItems: primaryItems,
        toItems: primaryItems,
        proposedFromItems: proposed,
        proposedToItems: proposed,
      },
      "the grouped drag path keeps the standalone payload shape with member IDs"
    );
    assert.strictEqual(
      onMove.firstCall.args[0].fromItems,
      primaryItems,
      "the drag payload carries the live member items reference"
    );
    assert.strictEqual(
      onMove.firstCall.args[0].proposedFromItems,
      onMove.firstCall.args[0].proposedToItems,
      "an in-list grouped drag shares one proposed array"
    );
    assert.strictEqual(
      announce.callCount,
      1,
      "the grouped in-list drag announces exactly once"
    );
    assert.strictEqual(
      announce.firstCall.args[0],
      `Moved ${label(movedItem)} to position ${toIndex + 1} of ${proposed.length}`,
      "an in-list grouped drag uses the standard announcement"
    );
  });

  test("DReorderableList commits a cross-list drag with frozen source slots", async function (assert) {
    const primaryItems = [
      { id: "primary-alpha", name: "Primary Alpha" },
      { id: "primary-fixed", name: "Primary Fixed" },
      { id: "primary-charlie", name: "Primary Charlie" },
    ];
    const secondaryItems = [
      { id: "secondary-alpha", name: "Secondary Alpha" },
      { id: "secondary-bravo", name: "Secondary Bravo" },
    ];
    const movedItem = primaryItems[0];
    const frozenItem = primaryItems[1];
    const targetItem = secondaryItems[0];
    const movable = (item) => item !== frozenItem;
    const proposedFromItems = [primaryItems[2], frozenItem];
    const proposedToItems = [secondaryItems[0], movedItem, secondaryItems[1]];
    const fromIndex = primaryItems.indexOf(movedItem);
    const toIndex = secondaryItems.indexOf(targetItem) + 1;
    const onMove = sinon.spy();
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{onMove}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="primary"
            @listLabel="Primary links"
            @items={{primaryItems}}
            @key="id"
            @label={{label}}
            @movable={{movable}}
            id="cross-primary-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
          <DReorderableList
            @group={{group}}
            @listId="secondary"
            @listLabel="Secondary links"
            @items={{secondaryItems}}
            @key="id"
            @label={{label}}
            id="cross-secondary-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    const source = rowSelector(movedItem.id, "#cross-primary-list");
    const target = rowSelector(targetItem.id, "#cross-secondary-list");
    assertDragReady(assert, source, target);
    await simulateDrag(source, target, {
      dataTransfer: new DataTransfer(),
      targetCoordinates: dropCoordinates(target, "after"),
    });

    assert.strictEqual(
      onMove.callCount,
      1,
      "one cross-list drop calls the group callback exactly once"
    );
    assert.deepEqual(
      onMove.firstCall.args[0],
      {
        method: "drag",
        item: movedItem,
        fromList: "primary",
        toList: "secondary",
        fromIndex,
        toIndex,
        fromItems: primaryItems,
        toItems: secondaryItems,
        proposedFromItems,
        proposedToItems,
      },
      "the cross-list drop reports both lists and their independent proposals"
    );
    assert.strictEqual(
      onMove.firstCall.args[0].fromItems,
      primaryItems,
      "fromItems is the live source array reference"
    );
    assert.strictEqual(
      onMove.firstCall.args[0].toItems,
      secondaryItems,
      "toItems is the live destination array reference"
    );
    assert.deepEqual(
      onMove.firstCall.args[0].proposedFromItems,
      proposedFromItems,
      "removal refills movable source slots while the frozen row keeps index one"
    );
    assert.deepEqual(
      onMove.firstCall.args[0].proposedToItems,
      proposedToItems,
      "an after drop inserts after the destination row without same-list correction"
    );
    assert.strictEqual(
      announce.callCount,
      1,
      "the cross-list move announces exactly once"
    );
    assert.strictEqual(
      announce.firstCall.args[0],
      `Moved ${label(movedItem)} to Secondary links, position ${toIndex + 1} of ${proposedToItems.length}`,
      "the cross-list announcement names the labelled destination list"
    );
  });

  test("DReorderableList keeps step boundaries within each group member", async function (assert) {
    const primaryItems = [{ id: "primary-alpha", name: "Primary Alpha" }];
    const secondaryItems = [
      { id: "secondary-alpha", name: "Secondary Alpha" },
      { id: "secondary-bravo", name: "Secondary Bravo" },
    ];
    const onMove = sinon.spy();
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{onMove}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="primary"
            @items={{primaryItems}}
            @key="id"
            @label={{label}}
            id="boundary-primary-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
          <DReorderableList
            @group={{group}}
            @listId="secondary"
            @items={{secondaryItems}}
            @key="id"
            @label={{label}}
            id="boundary-secondary-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    await openMoveMenu(secondaryItems[0].id, "#boundary-secondary-list");
    assert
      .dom(moveItemSelector("up"))
      .isDisabled(
        "the first row of the second member cannot step into the preceding member"
      );

    // A member's boundary is spoken by the accelerator, the one path that still
    // reaches it now the destination declines the press itself.
    await moveViaChord(secondaryItems[0].id, "up", "#boundary-secondary-list");

    assert.strictEqual(
      onMove.callCount,
      0,
      "a refused local boundary move commits nothing to the group"
    );
    assert.true(
      announce.calledOnceWith("Secondary Alpha is already first"),
      "and the reader is told they reached the member's boundary"
    );
  });

  test("DReorderableList accepts a cross-list drop on an empty member root", async function (assert) {
    const primaryItems = [{ id: "primary-alpha", name: "Primary Alpha" }];
    const emptyItems = [];
    const movedItem = primaryItems[0];
    const onMove = sinon.spy();
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{onMove}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="primary"
            @items={{primaryItems}}
            @key="id"
            @label={{label}}
            id="empty-source-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
          <DReorderableList
            @group={{group}}
            @listId="empty"
            @listLabel="Empty links"
            @items={{emptyItems}}
            @key="id"
            @label={{label}}
            id="empty-target-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    const source = rowSelector(movedItem.id, "#empty-source-list");
    const target = "#empty-target-list";
    assert
      .dom(target)
      .hasClass(
        "d-reorderable-list",
        "the empty destination keeps the standard list root"
      )
      .hasAttribute(
        "data-drop-target",
        "",
        "an empty grouped member registers its root as a drop target"
      );
    await simulateDrag(source, target, {
      dataTransfer: new DataTransfer(),
    });

    assert.strictEqual(
      onMove.callCount,
      1,
      "dropping on the empty root calls the group callback once"
    );
    assert.deepEqual(
      onMove.firstCall.args[0],
      {
        method: "drag",
        item: movedItem,
        fromList: "primary",
        toList: "empty",
        fromIndex: 0,
        toIndex: 0,
        fromItems: primaryItems,
        toItems: emptyItems,
        proposedFromItems: [],
        proposedToItems: [movedItem],
      },
      "the empty-root drop removes the source and inserts at destination index zero"
    );
    assert.strictEqual(
      announce.callCount,
      1,
      "the empty-root drop announces exactly once"
    );
    assert.strictEqual(
      announce.firstCall.args[0],
      `Moved ${label(movedItem)} to Empty links, position 1 of 1`,
      "the empty destination announcement measures its proposed one-item list"
    );
  });

  test("DReorderableList keeps non-empty member roots out of drop targeting", async function (assert) {
    const primaryItems = [{ id: "primary-alpha", name: "Primary Alpha" }];
    const secondaryItems = [{ id: "secondary-alpha", name: "Secondary Alpha" }];

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{noop}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="primary"
            @items={{primaryItems}}
            @key="id"
            @label={{label}}
            id="non-empty-primary-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
          <DReorderableList
            @group={{group}}
            @listId="secondary"
            @items={{secondaryItems}}
            @key="id"
            @label={{label}}
            id="non-empty-secondary-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    for (const root of [
      "#non-empty-primary-list",
      "#non-empty-secondary-list",
    ]) {
      assert
        .dom(root)
        .doesNotHaveAttribute(
          "data-drop-target",
          `${root} does not register its non-empty root for drops`
        );
      assert
        .dom(`${root} > .d-reorderable-list__row`)
        .hasAttribute(
          "data-drop-target",
          "",
          `${root} continues to accept drops on its row`
        );
    }
  });

  test("DReorderableList uses the standard cross-list announcement without a destination label", async function (assert) {
    const primaryItems = [{ id: "primary-alpha", name: "Primary Alpha" }];
    const secondaryItems = [{ id: "secondary-alpha", name: "Secondary Alpha" }];
    const movedItem = primaryItems[0];
    const targetItem = secondaryItems[0];
    const proposedToItems = [movedItem, targetItem];
    const onMove = sinon.spy();
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{onMove}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="primary"
            @listLabel="Primary links"
            @items={{primaryItems}}
            @key="id"
            @label={{label}}
            id="unlabelled-primary-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
          <DReorderableList
            @group={{group}}
            @listId="secondary"
            @items={{secondaryItems}}
            @key="id"
            @label={{label}}
            id="unlabelled-secondary-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    const source = rowSelector(movedItem.id, "#unlabelled-primary-list");
    const target = rowSelector(targetItem.id, "#unlabelled-secondary-list");
    assertDragReady(assert, source, target);
    await simulateDrag(source, target, {
      dataTransfer: new DataTransfer(),
      targetCoordinates: dropCoordinates(target, "before"),
    });

    assert.strictEqual(
      onMove.callCount,
      1,
      "the unlabelled destination still commits one cross-list move"
    );
    assert.strictEqual(
      announce.callCount,
      1,
      "the unlabelled destination still announces exactly once"
    );
    assert.strictEqual(
      announce.firstCall.args[0],
      `Moved ${label(movedItem)} to position 1 of ${proposedToItems.length}`,
      "the fallback announcement omits a destination list name"
    );
  });

  test("DReorderableList isolates grouped and standalone drag surfaces", async function (assert) {
    const groupedItems = [
      { id: "grouped-alpha", name: "Grouped Alpha" },
      { id: "grouped-bravo", name: "Grouped Bravo" },
    ];
    const standaloneItems = [
      { id: "standalone-alpha", name: "Standalone Alpha" },
      { id: "standalone-bravo", name: "Standalone Bravo" },
    ];
    const groupOnMove = sinon.spy();
    const standaloneOnMove = sinon.spy();
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{groupOnMove}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="grouped"
            @items={{groupedItems}}
            @key="id"
            @label={{label}}
            id="isolated-grouped-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </DReorderableListGroup>
        <DReorderableList
          @items={{standaloneItems}}
          @key="id"
          @label={{label}}
          @onMove={{standaloneOnMove}}
          id="isolated-standalone-list"
        >
          <:row as |item|>
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </:row>
        </DReorderableList>
      </template>
    );

    const groupedSource = rowSelector(
      groupedItems[0].id,
      "#isolated-grouped-list"
    );
    const groupedTarget = rowSelector(
      groupedItems[1].id,
      "#isolated-grouped-list"
    );
    const standaloneSource = rowSelector(
      standaloneItems[0].id,
      "#isolated-standalone-list"
    );
    const standaloneTarget = rowSelector(
      standaloneItems[1].id,
      "#isolated-standalone-list"
    );

    await simulateDrag(groupedSource, standaloneTarget, {
      dataTransfer: new DataTransfer(),
      targetCoordinates: dropCoordinates(standaloneTarget, "before"),
    });

    await simulateDrag(standaloneSource, groupedTarget, {
      dataTransfer: new DataTransfer(),
      targetCoordinates: dropCoordinates(groupedTarget, "before"),
    });

    assert.strictEqual(
      groupOnMove.callCount,
      0,
      "the group rejects the standalone drag"
    );
    assert.strictEqual(
      standaloneOnMove.callCount,
      0,
      "the standalone list rejects the grouped drag"
    );
    assert.strictEqual(
      announce.callCount,
      0,
      "rejected drags across the isolation boundary are silent"
    );
  });

  test("a list torn down with its menu open leaves nothing registered", async function (assert) {
    // The menu's content is rendered by the app-root host and its lifecycle is
    // the service's, so neither ends when the list does. Without the list
    // cascading destruction into the coordinator, the instance stays in the
    // service's registry for the life of the app, holding the trigger element
    // and, through the menu data, the list itself.
    const items = objectItems();
    const state = new (class {
      @tracked showList = true;
    })();
    const menu = this.owner.lookup("service:menu");

    await render(
      <template>
        <DMenus />
        {{#if state.showList}}
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            id="teardown-menu-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        {{/if}}
      </template>
    );

    await openMoveMenu("alpha", "#teardown-menu-list");
    assert.dom(".d-reorderable-list__move-item").exists("the menu is open");
    assert.strictEqual(
      menu.registeredMenus.size,
      1,
      "and the service is holding it"
    );

    state.showList = false;
    await settled();

    assert
      .dom("#teardown-menu-list")
      .doesNotExist("the list is fully unrendered with its menu still open");
    assert
      .dom(".d-reorderable-list__move-item")
      .doesNotExist("no menu content outlives the list that opened it");
    assert.strictEqual(
      menu.registeredMenus.size,
      0,
      "and nothing is left registered with the service"
    );
  });

  test("DReorderableList refuses a drop after the source member is torn down", async function (assert) {
    const primaryItems = [{ id: "primary-alpha", name: "Primary Alpha" }];
    const secondaryItems = [{ id: "secondary-alpha", name: "Secondary Alpha" }];
    const state = new (class {
      @tracked showPrimary = true;
    })();
    const onMove = sinon.spy();
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{onMove}} as |group|>
          {{#if state.showPrimary}}
            <DReorderableList
              @group={{group}}
              @listId="primary"
              @items={{primaryItems}}
              @key="id"
              @label={{label}}
              id="teardown-primary-list"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          {{/if}}
          <DReorderableList
            @group={{group}}
            @listId="secondary"
            @items={{secondaryItems}}
            @key="id"
            @label={{label}}
            id="teardown-secondary-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    const source = rowSelector(primaryItems[0].id, "#teardown-primary-list");
    const sourceHandle = `${source} .d-reorderable-list__handle`;
    const target = rowSelector(
      secondaryItems[0].id,
      "#teardown-secondary-list"
    );
    const dataTransfer = new DataTransfer();
    assert.dom(source).hasAttribute("data-drag-source", "");
    assert.dom(target).hasAttribute("data-drop-target", "");
    await dragEvent(sourceHandle, "dragstart", {
      dataTransfer,
      ...centerOf(sourceHandle),
    });

    state.showPrimary = false;
    await settled();

    assert
      .dom("#teardown-primary-list")
      .doesNotExist("the source member is fully unrendered mid-drag");
    const targetCoordinates = dropCoordinates(target, "before");
    await dragEvent(target, "dragenter", {
      dataTransfer,
      ...targetCoordinates,
    });
    await dragEvent(target, "dragover", {
      dataTransfer,
      ...targetCoordinates,
    });
    await dragEvent(target, "drop", {
      dataTransfer,
      ...targetCoordinates,
    });

    assert.strictEqual(
      onMove.callCount,
      0,
      "the group refuses a drop whose source membership is gone"
    );
    assert.strictEqual(
      announce.callCount,
      0,
      "the refused teardown drop makes no announcement"
    );
  });

  test("DReorderableList rejects duplicate group listId registrations", async function (assert) {
    const primaryItems = [{ id: "primary-alpha", name: "Primary Alpha" }];
    const secondaryItems = [{ id: "secondary-alpha", name: "Secondary Alpha" }];
    let raised;

    setupOnerror((error) => {
      raised = error;
    });

    try {
      await render(
        <template>
          <DMenus />
          <DReorderableListGroup @onMove={{noop}} as |group|>
            <DReorderableList
              @group={{group}}
              @listId="duplicate"
              @items={{primaryItems}}
              @key="id"
              @label={{label}}
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
            <DReorderableList
              @group={{group}}
              @listId="duplicate"
              @items={{secondaryItems}}
              @key="id"
              @label={{label}}
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );
    } finally {
      resetOnerror();
    }

    assert.true(
      /Assertion Failed:.*(duplicate|list.?id|unique)/i.test(
        raised?.message ?? ""
      ),
      "duplicate listId registration triggers a development assertion"
    );
  });
});

module(
  "Integration | ui-kit | DReorderableList | keyboard and menu",
  function (hooks) {
    setupRenderingTest(hooks);

    const moveKeys = [
      "method",
      "item",
      "fromList",
      "toList",
      "fromIndex",
      "toIndex",
      "fromItems",
      "toItems",
      "proposedFromItems",
      "proposedToItems",
    ].sort();

    test("every movable row renders one handle carrying its description", async function (assert) {
      const items = objectItems();
      const movable = (item) => item.id !== "bravo";

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @movable={{movable}}
            @onMove={{noop}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      assert
        .dom(".d-reorderable-list__handle")
        .exists({ count: 2 }, "only the movable rows carry a handle");
      assert
        .dom(handleSelector("bravo"))
        .doesNotExist("a frozen row renders no control at all");

      for (const key of ["alpha", "charlie"]) {
        const handle = find(handleSelector(key));
        const describedBy = handle.getAttribute("aria-describedby");
        assert
          .dom(`#${describedBy}`)
          .hasText(
            "Use the arrow keys to move between rows. Press Enter for move options.",
            `${key}'s handle is described by the interaction hint`
          );
        assert.true(
          handle.contains(find(`#${describedBy}`)),
          `${key}'s description belongs to its own control, not to the list`
        );
      }
    });

    test("the handle names its row and reports its menu state", async function (assert) {
      const items = objectItems();

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      assert
        .dom(handleSelector("bravo"))
        .hasAria(
          "label",
          "Reorder Bravo",
          "the handle names which row it moves"
        )
        .hasAria("expanded", "false");

      await openMoveMenu("bravo");

      assert
        .dom(handleSelector("bravo"))
        .hasAria(
          "expanded",
          "true",
          "the open menu is reported on the trigger"
        );
    });

    test("every handle is a tab stop, and arrows walk between them", async function (assert) {
      const items = objectItems();

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      const tabbable = findAll(".d-reorderable-list__handle").filter(
        (element) => element.getAttribute("tabindex") !== "-1"
      );
      assert.strictEqual(
        tabbable.length,
        items.length,
        "every row's handle is reachable by Tab, in DOM order with the row's own controls"
      );

      await focus(handleSelector("alpha"));
      await triggerKeyEvent(handleSelector("alpha"), "keydown", "ArrowDown");

      assert
        .dom(handleSelector("bravo"))
        .isFocused(
          "a plain arrow is an accelerator that moves focus, not the row"
        );
      assert.deepEqual(
        renderedItemOrder(),
        ["alpha", "bravo", "charlie"],
        "and nothing reordered"
      );
    });

    test("the remove control names what it removes and reports the item", async function (assert) {
      const items = objectItems();
      const removed = [];
      const onRemove = (item) => removed.push(item.id);

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @onRemove={{onRemove}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      assert
        .dom(`${rowSelector("bravo")} .d-reorderable-list__remove`)
        .hasAria(
          "label",
          "Remove Bravo",
          "an icon-only control still says what it removes"
        );

      await click(`${rowSelector("bravo")} .d-reorderable-list__remove`);

      assert.deepEqual(removed, ["bravo"], "the item itself is reported");
    });

    test("removal is announced and leaves focus on the row that took its place", async function (assert) {
      const state = new (class {
        @tracked items = objectItems();
      })();
      const onRemove = (item) => {
        state.items = state.items.filter((candidate) => candidate !== item);
      };
      // Spied rather than read back off the service: an announcement schedules
      // its own clear, and `settled()` waits that timer out.
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{state.items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @onRemove={{onRemove}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      await click(`${rowSelector("bravo")} .d-reorderable-list__remove`);

      assert.strictEqual(
        announce.callCount,
        1,
        "one announcement per removal, not one per rerender"
      );
      assert.strictEqual(
        announce.firstCall.args[0],
        "Removed Bravo",
        "a row leaving under the reader is not a silent no-op"
      );
      assert
        .dom(`${rowSelector("charlie")} .d-reorderable-list__remove`)
        .isFocused(
          "focus lands on the row that moved up, so a second removal needs no re-entry"
        );
    });

    test("a row refused by @removable renders no remove control", async function (assert) {
      const items = objectItems();
      const removable = (item) => item.id !== "bravo";

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @onRemove={{noop}}
            @removable={{removable}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      assert
        .dom(`${rowSelector("bravo")} .d-reorderable-list__remove`)
        .doesNotExist(
          "a protected row carries no dead control, exactly as a frozen row carries no handle"
        );
      assert
        .dom(`${rowSelector("alpha")} .d-reorderable-list__remove`)
        .exists("while the rows that can go still offer it");
    });

    test("opening the menu hands focus to its first destination", async function (assert) {
      const items = objectItems();

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      await openMoveMenu("bravo");

      assert
        .dom(moveItemSelector("top"))
        .isFocused(
          "focus moves into the menu rather than staying on the trigger it was opened from"
        );
    });

    test("moving the cursor closes a menu it would otherwise leave behind", async function (assert) {
      const items = objectItems();

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      await openMoveMenu("alpha");
      assert
        .dom(".d-reorderable-list__move-item")
        .exists("the menu is open on the first row");

      await triggerKeyEvent(handleSelector("alpha"), "keydown", "ArrowDown");

      assert
        .dom(handleSelector("bravo"))
        .isFocused("the cursor still moves between rows");
      assert
        .dom(".d-reorderable-list__move-item")
        .doesNotExist(
          "and the menu closes rather than staying open over a row the cursor has left"
        );
      assert
        .dom(handleSelector("alpha"))
        .hasAria("expanded", "false", "the trigger reports itself closed");
    });

    test("tab order runs in DOM order through each row and its controls", async function (assert) {
      // The defect this replaced: a roving cursor over the handles interleaved
      // with the rows' own tab order, so a handle could not be reached from the
      // control sitting beside it.
      const items = objectItems();

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
              <button type="button" class={{concat "extra-" item.id}}>x</button>
            </:row>
          </DReorderableList>
        </template>
      );

      const order = findAll(
        ".d-reorderable-list__handle, [class^='extra-']"
      ).map((element) =>
        element.classList.contains("d-reorderable-list__handle")
          ? `handle-${element.closest("[data-reorderable-key]").dataset.reorderableKey}`
          : element.className
      );

      assert.deepEqual(
        order,
        [
          "handle-alpha",
          "extra-alpha",
          "handle-bravo",
          "extra-bravo",
          "handle-charlie",
          "extra-charlie",
        ],
        "each row's handle precedes its own controls and nothing interleaves"
      );
    });

    test("clicking a row's non-interactive area moves the cursor there", async function (assert) {
      const items = objectItems();

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      await click(`${rowSelector("charlie")} [data-test-item]`);

      assert
        .dom(handleSelector("charlie"))
        .isFocused("the pointer and the keyboard agree on where 'here' is");
    });

    test("a menu move emits the exact payload and one announcement", async function (assert) {
      const items = trackedArray(objectItems());
      const moves = [];
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
      const handleMove = (move) => {
        moves.push(move);
        items.splice(0, items.length, ...move.proposedToItems);
      };

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{handleMove}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      await moveVia("alpha", "down");

      assert.strictEqual(moves.length, 1, "one commit for one chosen move");
      const [move] = moves;
      assert.deepEqual(Object.keys(move).sort(), moveKeys, "the payload shape");
      assert.strictEqual(move.method, "menu", "the method names the menu");
      assert.strictEqual(move.item.id, "alpha");
      assert.strictEqual(move.fromIndex, 0);
      assert.strictEqual(move.toIndex, 1);
      assert.deepEqual(
        move.proposedToItems.map((item) => item.id),
        ["bravo", "alpha", "charlie"]
      );
      assert.deepEqual(renderedItemOrder(), ["bravo", "alpha", "charlie"]);

      assert.true(
        announce.calledOnceWith("Moved Alpha to position 2 of 3"),
        "exactly one announcement, naming the item and its new position"
      );
    });

    test("move to top and move to bottom jump the whole distance in one commit", async function (assert) {
      const items = trackedArray(objectItems());
      const moves = [];
      const handleMove = (move) => {
        moves.push(move);
        items.splice(0, items.length, ...move.proposedToItems);
      };

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{handleMove}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      await moveVia("charlie", "top");

      assert.deepEqual(renderedItemOrder(), ["charlie", "alpha", "bravo"]);
      assert.strictEqual(
        moves.length,
        1,
        "one commit, not one per position crossed"
      );

      await moveVia("charlie", "bottom");

      assert.deepEqual(renderedItemOrder(), ["alpha", "bravo", "charlie"]);
      assert.strictEqual(moves.length, 2);
    });

    test("opening skips destinations the row cannot use", async function (assert) {
      // The first row can go nowhere but down, so a menu that opened on its
      // own first item would put focus on something Enter cannot action.
      const items = objectItems();

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      await openMoveMenu("alpha");

      assert
        .dom(moveItemSelector("top"))
        .isDisabled("the first row cannot go to the top");
      assert
        .dom(moveItemSelector("down"))
        .isFocused("so focus lands on the first destination it can use");
    });

    test("boundary destinations stay in the menu, disabled and refusing", async function (assert) {
      const items = trackedArray(objectItems());
      const moves = [];
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
      const handleMove = (move) => moves.push(move);

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{handleMove}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      await openMoveMenu("alpha");

      assert
        .dom(".d-reorderable-list__move-item")
        .exists(
          { count: 4 },
          "the menu keeps its shape on the first row rather than shrinking"
        );
      for (const target of ["top", "up"]) {
        assert
          .dom(moveItemSelector(target))
          .isDisabled(`${target} is refused, and inert rather than marked`);
      }
      for (const target of ["down", "bottom"]) {
        assert
          .dom(moveItemSelector(target))
          .isNotDisabled(`${target} is available`);
      }

      // The accelerator is the path that still reaches a boundary, the menu's
      // own destination having declined the press before anything ran.
      await moveViaChord("alpha", "up");

      assert.deepEqual(moves, [], "a refused move commits nothing");
      assert.deepEqual(renderedItemOrder(), ["alpha", "bravo", "charlie"]);
      assert.true(
        announce.calledOnceWith("Alpha is already first"),
        "and the refusal is spoken rather than being a silent no-op"
      );
    });

    test("a single movable item has no destination at all", async function (assert) {
      const items = [{ id: "alpha", name: "Alpha" }];

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      await openMoveMenu("alpha");

      for (const target of ["top", "up", "down", "bottom"]) {
        assert
          .dom(moveItemSelector(target))
          .isDisabled(`${target} leads nowhere`);
      }

      assert
        .dom(handleSelector("alpha"))
        .isFocused(
          "and with nothing to focus, focus stays on the handle rather than being stranded on the document"
        );
    });

    test("Alt with an arrow moves the row and keeps focus on its handle", async function (assert) {
      const items = trackedArray(objectItems());
      const moves = [];
      const handleMove = (move) => {
        moves.push(move);
        items.splice(0, items.length, ...move.proposedToItems);
      };

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{handleMove}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      await moveViaChord("alpha", "down");

      assert.deepEqual(renderedItemOrder(), ["bravo", "alpha", "charlie"]);
      assert.strictEqual(moves.length, 1);
      assert.strictEqual(
        moves[0].method,
        "keyboard",
        "the method distinguishes the chord from the menu"
      );
      assert
        .dom(handleSelector("alpha"))
        .isFocused(
          "focus follows the row it moved, so a second press is possible"
        );

      await triggerKeyEvent(document.activeElement, "keydown", "ArrowUp", {
        altKey: true,
      });

      assert.deepEqual(
        renderedItemOrder(),
        ["alpha", "bravo", "charlie"],
        "and the opposite chord reverses it"
      );
    });

    test("Alt with Home or End sends the row to an end", async function (assert) {
      const items = trackedArray(objectItems());
      const handleMove = (move) => {
        items.splice(0, items.length, ...move.proposedToItems);
      };

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{handleMove}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      await moveViaChord("alpha", "end");
      assert.deepEqual(renderedItemOrder(), ["bravo", "charlie", "alpha"]);

      await moveViaChord("alpha", "top");
      assert.deepEqual(renderedItemOrder(), ["alpha", "bravo", "charlie"]);
    });

    test("a chord at a boundary announces without committing", async function (assert) {
      const items = trackedArray(objectItems());
      const moves = [];
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
      const handleMove = (move) => moves.push(move);

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{handleMove}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      await moveViaChord("charlie", "down");

      assert.deepEqual(moves, [], "nothing committed past the end");
      assert.true(
        announce.calledOnceWith("Charlie is already last"),
        "arriving at the end is reported"
      );
    });

    test("a run of chord moves speaks position only until it settles", async function (assert) {
      const items = trackedArray(objectItems());
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
      const handleMove = (move) => {
        items.splice(0, items.length, ...move.proposedToItems);
      };

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{handleMove}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      // Dispatched directly, and both in one turn: `triggerKeyEvent` awaits
      // `settled()`, which drains the run's settle timer and would end the run
      // between the two presses. A held key repeats far faster than that.
      const press = () =>
        document.activeElement.dispatchEvent(
          new KeyboardEvent("keydown", {
            key: "ArrowDown",
            altKey: true,
            bubbles: true,
          })
        );
      find(handleSelector("alpha")).focus();
      press();
      press();
      await settled();

      assert.deepEqual(renderedItemOrder(), ["bravo", "charlie", "alpha"]);
      assert.deepEqual(
        announce.getCalls().map((call) => call.args[0]),
        ["2 of 3", "3 of 3", "Moved Alpha to position 3 of 3"],
        "terse while the run continues, the full sentence once it settles"
      );
    });

    test("a run cut short by teardown does not speak for a list that is gone", async function (assert) {
      const items = trackedArray(objectItems());
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
      const state = new (class {
        @tracked show = true;
      })();
      const handleMove = (move) => {
        items.splice(0, items.length, ...move.proposedToItems);
      };

      await render(
        <template>
          <DMenus />
          {{#if state.show}}
            <DReorderableList
              @items={{items}}
              @key="id"
              @label={{label}}
              @onMove={{handleMove}}
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          {{/if}}
        </template>
      );

      // Dispatched directly rather than through `triggerKeyEvent`, which awaits
      // `settled()` and would drain the settle timer before the teardown.
      find(handleSelector("alpha")).focus();
      document.activeElement.dispatchEvent(
        new KeyboardEvent("keydown", {
          key: "ArrowDown",
          altKey: true,
          bubbles: true,
        })
      );

      state.show = false;
      await settled();

      assert.deepEqual(
        announce.getCalls().map((call) => call.args[0]),
        ["2 of 3"],
        "the in-run position stands, and the settle timer speaks nothing after teardown"
      );
    });

    test("a menu move always speaks the full sentence", async function (assert) {
      const items = trackedArray(objectItems());
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
      const handleMove = (move) => {
        items.splice(0, items.length, ...move.proposedToItems);
      };

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{handleMove}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      await moveVia("alpha", "down");
      await moveVia("alpha", "down");

      assert.deepEqual(
        announce.getCalls().map((call) => call.args[0]),
        ["Moved Alpha to position 2 of 3", "Moved Alpha to position 3 of 3"],
        "a deliberate single choice is never abbreviated"
      );
    });

    test("a chord hops frozen rows", async function (assert) {
      const items = trackedArray(objectItems());
      const movable = (item) => item.id !== "bravo";
      const handleMove = (move) => {
        items.splice(0, items.length, ...move.proposedToItems);
      };

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @movable={{movable}}
            @onMove={{handleMove}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      await moveViaChord("alpha", "down");

      assert.deepEqual(
        renderedItemOrder(),
        ["charlie", "bravo", "alpha"],
        "the frozen row keeps its exact visible slot while the others swap"
      );
    });

    test("the handle is still the drag source", async function (assert) {
      const items = objectItems();

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      assert
        .dom(rowSelector("alpha"))
        .hasAttribute(
          "data-drag-source",
          "",
          "the row is what a drop target receives and what the preview shows"
        );
    });

    test("an unmodified Escape does not reorder anything", async function (assert) {
      const items = trackedArray(objectItems());
      const moves = [];
      const handleMove = (move) => moves.push(move);

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{handleMove}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      await focus(handleSelector("bravo"));
      await triggerKeyEvent(handleSelector("bravo"), "keydown", "Escape");

      assert.deepEqual(moves, [], "there is no mode for Escape to unwind");
      assert.deepEqual(renderedItemOrder(), ["alpha", "bravo", "charlie"]);
    });

    test("index identity is safe now that nothing is held across a move", async function (assert) {
      const items = trackedArray(["alpha", "bravo", "charlie"]);
      const handleMove = (move) => {
        items.splice(0, items.length, ...move.proposedToItems);
      };

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key={{INDEX_KEY}}
            @label={{label}}
            @onMove={{handleMove}}
          >
            <:row as |item|>
              <span data-test-item={{item}}>{{item}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      await moveVia("0", "down");

      assert.deepEqual(
        renderedItemOrder(),
        ["bravo", "alpha", "charlie"],
        "a position-keyed list reorders without a held key to invalidate"
      );
    });
  }
);
