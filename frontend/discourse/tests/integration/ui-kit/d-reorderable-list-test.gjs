import { tracked } from "@glimmer/tracking";
import { trackedArray } from "@ember/reactive/collections";
import {
  click,
  fillIn,
  find,
  findAll,
  render,
  resetOnerror,
  settled,
  setupOnerror,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import loadAccessibleName from "discourse/lib/load-accessible-name";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  assertDragRegistered,
  centerOf,
  dragEvent,
  simulateDrag,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import DReorderableListGroup from "discourse/ui-kit/d-reorderable-list-group";

const noop = () => {};
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

function arrowSelector(key, direction, root = "") {
  const child = direction === "up" ? "first-child" : "last-child";
  return `${rowSelector(key, root)} .d-reorder-buttons__button:${child}`;
}

function assertArrowReady(assert, key, direction) {
  const selector = arrowSelector(key, direction);
  assert
    .dom(selector)
    .exists(`the ${direction} arrow renders for the interaction`);
  return selector;
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
    .dom(`${source} .d-reorderable-list__handle`)
    .hasAttribute(
      "data-drag-source",
      "",
      "the source handle is registered for dragging"
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
        <DReorderableList
          @items={{items}}
          @key="identity.value"
          @label={{label}}
          @onMove={{noop}}
        >
          <:default as |item row|>
            <span
              class="row-content"
              data-test-item={{item.id}}
              data-index={{row.index}}
              data-first={{if row.isFirst "true" "false"}}
              data-last={{if row.isLast "true" "false"}}
              data-movable={{if row.movable "true" "false"}}
              data-dragging={{if row.isDragging "true" "false"}}
            >{{item.name}}</span>
          </:default>
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
        .dom(`${row} > .d-reorderable-list__handle`)
        .hasClass("d-drag-handle", `${itemLabel} uses DDragHandle`)
        .hasAttribute(
          "aria-hidden",
          "true",
          `${itemLabel}'s handle is decorative`
        )
        .hasAttribute(
          "title",
          `Drag ${itemLabel}`,
          `${itemLabel}'s handle tooltip names the item`
        );
      assert
        .dom(`${row} > .d-reorderable-list__arrows`)
        .hasClass("d-reorder-buttons", `${itemLabel} uses DReorderButtons`)
        .doesNotHaveClass(
          "--inline",
          `${itemLabel}'s arrows use the stacked layout by default`
        );
      assert
        .dom(arrowSelector(key, "up"))
        .hasAria(
          "label",
          `Move ${itemLabel} up`,
          `the up arrow names ${itemLabel}`
        );
      assert
        .dom(arrowSelector(key, "down"))
        .hasAria(
          "label",
          `Move ${itemLabel} down`,
          `the down arrow names ${itemLabel}`
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
        )
        .hasAttribute(
          "data-dragging",
          "false",
          `${itemLabel} is initially not dragging`
        );
    }

    assert.deepEqual(
      Array.from(find(rowSelector(items[0].identity.value)).children).map(
        (element) => element.className
      ),
      [
        "d-drag-handle d-reorderable-list__handle",
        "d-reorder-buttons d-reorderable-list__arrows",
        "row-content",
      ],
      "controls are the first children, before the row block"
    );
  });

  test("renders header and static blocks around the rows", async function (assert) {
    const items = objectItems().slice(0, 2);

    await render(
      <template>
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{noop}}
        >
          <:header><li data-slot="header">Header</li></:header>
          <:default as |item|><span
              data-test-item={{item.id}}
            >{{item.name}}</span></:default>
          <:static><li data-slot="static">Static</li></:static>
        </DReorderableList>
      </template>
    );

    assert.dom(".d-reorderable-list").exists("the list root renders");
    assert.deepEqual(
      Array.from(find(".d-reorderable-list").children).map(
        (element) => element.dataset.slot ?? element.dataset.reorderableKey
      ),
      ["header", ...items.map((item) => item.id), "static"],
      "the header precedes every row and the static block follows every row"
    );
    assert
      .dom("[data-slot='static'] .d-reorderable-list__handle")
      .doesNotExist("static content receives no reorder controls");
  });

  test("renders the empty block in the rows position", async function (assert) {
    const items = [];

    await render(
      <template>
        <DReorderableList @items={{items}} @label={{label}} @onMove={{noop}}>
          <:header><li data-slot="header">Header</li></:header>
          <:default as |item|><span
              data-test-item={{item}}
            >{{item}}</span></:default>
          <:empty><li data-slot="empty">Nothing here</li></:empty>
          <:static><li data-slot="static">Static</li></:static>
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
      ["header", "empty", "static"],
      "the empty block replaces the rows between header and static content"
    );
  });

  test("supports custom shell tags, roles, and attributes", async function (assert) {
    const items = objectItems().slice(0, 1);

    await render(
      <template>
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
          as |item|
        >
          <span data-test-item={{item.id}}>{{item.name}}</span>
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
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{noop}}
          @rowClass="string-one string-two"
          id="string-classes"
          as |item|
        ><span
            data-test-item={{item.id}}
          >{{item.name}}</span></DReorderableList>
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{noop}}
          @movable={{movable}}
          @rowClass={{rowClass}}
          id="callback-classes"
          as |item|
        ><span
            data-test-item={{item.id}}
          >{{item.name}}</span></DReorderableList>
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

  test("places controls after row content when requested", async function (assert) {
    const items = objectItems().slice(0, 1);

    await render(
      <template>
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{noop}}
          @controls="end"
          as |item|
        ><span
            class="row-content"
            data-test-item={{item.id}}
          >{{item.name}}</span></DReorderableList>
      </template>
    );

    assert
      .dom(rowSelector(items[0].id))
      .exists("the row renders before its child order is inspected");
    assert.deepEqual(
      Array.from(find(rowSelector(items[0].id)).children).map(
        (element) => element.className
      ),
      [
        "row-content",
        "d-drag-handle d-reorderable-list__handle",
        "d-reorder-buttons d-reorderable-list__arrows",
      ],
      "end controls follow the row block while retaining handle-then-arrows order"
    );
  });

  test("threads inline arrow layout and reveal control visibility", async function (assert) {
    const items = objectItems().slice(0, 1);

    await render(
      <template>
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{noop}}
          @arrowsLayout="inline"
          @controlsVisibility="reveal"
          as |item|
        ><span
            data-test-item={{item.id}}
          >{{item.name}}</span></DReorderableList>
      </template>
    );

    assert
      .dom(".d-reorderable-list")
      .hasClass("--reveal-controls", "reveal visibility marks the list root");
    assert
      .dom(".d-reorderable-list__arrows")
      .hasClass("--inline", "inline layout is forwarded to DReorderButtons")
      .hasClass(
        "d-reorder-buttons",
        "the arrows keep their standalone base class"
      );
  });

  test("disabled removes every control and drag registration", async function (assert) {
    const items = objectItems();

    await render(
      <template>
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{noop}}
          @disabled={{true}}
          as |item|
        ><span
            data-test-item={{item.id}}
          >{{item.name}}</span></DReorderableList>
      </template>
    );

    assert
      .dom(".d-reorderable-list__row")
      .exists({ count: items.length }, "disabled lists still render every row");
    assert
      .dom(".d-reorderable-list__handle")
      .doesNotExist("disabled lists render no handles");
    assert
      .dom(".d-reorderable-list__arrows")
      .doesNotExist("disabled lists render no arrow pairs");
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
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{onMove}}
          @movable={{movable}}
        >
          <:default as |item row|>
            <span
              data-test-item={{item.id}}
              data-movable={{if row.movable "true" "false"}}
            >{{item.name}}</span>
          </:default>
        </DReorderableList>
      </template>
    );

    const frozenRow = rowSelector(frozen.id);
    assert
      .dom(`${frozenRow} .d-reorderable-list__handle`)
      .doesNotExist("a frozen row has no handle");
    assert
      .dom(`${frozenRow} .d-reorderable-list__arrows`)
      .doesNotExist("a frozen row has no arrows");
    assert
      .dom(frozenRow)
      .doesNotHaveAttribute("data-drop-target", "a frozen row refuses drops");
    assert
      .dom(`${frozenRow} [data-drag-source]`)
      .doesNotExist("a frozen row is not a drag source");

    await click(assertArrowReady(assert, items[0].id, "down"));

    assert.strictEqual(moves.length, 1, "one arrow press commits one move");
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
      .dom(`${source} .d-reorderable-list__handle`)
      .hasAttribute(
        "data-drag-source",
        "",
        "a movable row remains registered as a drag source"
      );
    assertDragRegistered(`${source} .d-reorderable-list__handle`, source);
    await simulateDrag(source, frozenRow, {
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

  test("disables only the boundary directions in the movable subsequence", async function (assert) {
    const items = objectItems();
    const movable = (item) => item !== items[1];

    await render(
      <template>
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{noop}}
          @movable={{movable}}
          as |item|
        ><span
            data-test-item={{item.id}}
          >{{item.name}}</span></DReorderableList>
      </template>
    );

    assert
      .dom(arrowSelector(items[0].id, "up"))
      .hasAttribute(
        "aria-disabled",
        "true",
        "the first movable item cannot move up"
      );
    assert
      .dom(arrowSelector(items[0].id, "down"))
      .doesNotHaveAttribute(
        "aria-disabled",
        "the first movable item can move down"
      );
    assert
      .dom(arrowSelector(items[2].id, "up"))
      .doesNotHaveAttribute(
        "aria-disabled",
        "the last movable item can move up"
      );
    assert
      .dom(arrowSelector(items[2].id, "down"))
      .hasAttribute(
        "aria-disabled",
        "true",
        "the last movable item cannot move down"
      );
  });

  test("disables both arrows for a single movable item", async function (assert) {
    const items = objectItems().slice(0, 1);

    await render(
      <template>
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{noop}}
          as |item|
        ><span
            data-test-item={{item.id}}
          >{{item.name}}</span></DReorderableList>
      </template>
    );

    assert
      .dom(arrowSelector(items[0].id, "up"))
      .hasAttribute(
        "aria-disabled",
        "true",
        "the sole movable item cannot move up"
      );
    assert
      .dom(arrowSelector(items[0].id, "down"))
      .hasAttribute(
        "aria-disabled",
        "true",
        "the sole movable item cannot move down"
      );
  });

  test("wrap exposes every arrow and cycles at both boundaries", async function (assert) {
    const items = objectItems();
    const moves = [];
    const onMove = (move) => moves.push(move);

    await render(
      <template>
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{onMove}}
          @wrap={{true}}
          as |item|
        ><span
            data-test-item={{item.id}}
          >{{item.name}}</span></DReorderableList>
      </template>
    );

    assert
      .dom(".d-reorder-buttons__button")
      .exists(
        { count: items.length * 2 },
        "wrap keeps both arrows on every row"
      )
      .doesNotHaveAttribute(
        "aria-disabled",
        "wrap leaves every direction available"
      );

    await click(assertArrowReady(assert, items[0].id, "up"));
    await click(assertArrowReady(assert, items.at(-1).id, "down"));

    assert.strictEqual(
      moves.length,
      2,
      "each boundary press commits exactly once"
    );
    assert.deepEqual(
      {
        fromIndex: moves[0].fromIndex,
        toIndex: moves[0].toIndex,
        proposed: moves[0].proposedToItems,
      },
      {
        fromIndex: 0,
        toIndex: items.length - 1,
        proposed: [items[1], items[2], items[0]],
      },
      "moving up from the front wraps to the end"
    );
    assert.deepEqual(
      {
        fromIndex: moves[1].fromIndex,
        toIndex: moves[1].toIndex,
        proposed: moves[1].proposedToItems,
      },
      {
        fromIndex: items.length - 1,
        toIndex: 0,
        proposed: [items[2], items[0], items[1]],
      },
      "moving down from the end wraps to the front"
    );
  });

  test("button moves emit the exact move payload and one default announcement", async function (assert) {
    const items = objectItems();
    const moves = [];
    const onMove = (move) => moves.push(move);
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{onMove}}
          as |item|
        ><span
            data-test-item={{item.id}}
          >{{item.name}}</span></DReorderableList>
      </template>
    );

    await click(assertArrowReady(assert, items[1].id, "up"));

    const proposed = [items[1], items[0], items[2]];
    assert.strictEqual(
      moves.length,
      1,
      "one button press calls onMove exactly once"
    );
    assert.deepEqual(
      moves[0],
      {
        method: "buttons",
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
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{onMove}}
          as |item|
        ><span
            data-test-item={{item.id}}
          >{{item.name}}</span></DReorderableList>
      </template>
    );

    await click(assertArrowReady(assert, sourceItems[1].id, "down"));

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
      .dom(arrowSelector(sourceItems[1].id, "down"))
      .isFocused("the pressed arrow regains focus after its keyed row moves");
  });

  test("an onMove false return vetoes the announcement", async function (assert) {
    const items = objectItems();
    const onMove = sinon.stub().returns(false);
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{onMove}}
          as |item|
        ><span
            data-test-item={{item.id}}
          >{{item.name}}</span></DReorderableList>
      </template>
    );

    await click(assertArrowReady(assert, items[1].id, "up"));

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
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{onMove}}
          @announceMove={{announceMove}}
          as |item|
        ><span
            data-test-item={{item.id}}
          >{{item.name}}</span></DReorderableList>
      </template>
    );

    await click(assertArrowReady(assert, items[1].id, "up"));

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
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{onMove}}
          @announceMove={{announceMove}}
          as |item|
        ><span
            data-test-item={{item.id}}
          >{{item.name}}</span></DReorderableList>
      </template>
    );

    await click(assertArrowReady(assert, items[1].id, "up"));

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
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{onMove}}
          as |item|
        ><span
            data-test-item={{item.id}}
          >{{item.name}}</span></DReorderableList>
      </template>
    );

    const source = rowSelector(items[0].id);
    const target = rowSelector(items[2].id);
    assertDragReady(assert, source, target);
    assertDragRegistered(`${source} .d-reorderable-list__handle`, target);
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
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{onMove}}
          as |item|
        ><span
            data-test-item={{item.id}}
          >{{item.name}}</span></DReorderableList>
      </template>
    );

    const source = rowSelector(items[2].id);
    const target = rowSelector(items[0].id);
    assertDragReady(assert, source, target);
    assertDragRegistered(`${source} .d-reorderable-list__handle`, target);
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
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{onMove}}
          as |item|
        ><span
            data-test-item={{item.id}}
          >{{item.name}}</span></DReorderableList>
      </template>
    );

    const source = rowSelector(items[0].id);
    const target = rowSelector(items[1].id);
    assertDragReady(assert, source, target);
    assertDragRegistered(`${source} .d-reorderable-list__handle`, target);
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
        <DReorderableList
          @items={{state.items}}
          @key="id"
          @label={{label}}
          @onMove={{onMove}}
        >
          <:default as |item row|><span
              data-test-item={{item.id}}
              data-dragging={{if row.isDragging "true" "false"}}
            >{{item.name}}</span></:default>
        </DReorderableList>
      </template>
    );

    const draggedKey = initialItems[1].id;
    const sourceHandle = `${rowSelector(draggedKey)} .d-reorderable-list__handle`;
    const dataTransfer = new DataTransfer();
    assert
      .dom(sourceHandle)
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
      .dom(`[data-test-item="${draggedKey}"]`)
      .hasAttribute(
        "data-dragging",
        "true",
        "the source yields its active drag state"
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
      .dom(`[data-test-item="${draggedKey}"]`)
      .hasAttribute(
        "data-dragging",
        "false",
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
        <DReorderableList
          @items={{firstItems}}
          @key="id"
          @label={{label}}
          @onMove={{firstOnMove}}
          id="first-list"
          as |item|
        ><span
            data-test-item={{item.id}}
          >{{item.name}}</span></DReorderableList>
        <DReorderableList
          @items={{secondItems}}
          @key="id"
          @label={{label}}
          @onMove={{secondOnMove}}
          id="second-list"
          as |item|
        ><span
            data-test-item={{item.id}}
          >{{item.name}}</span></DReorderableList>
      </template>
    );

    const source = rowSelector(firstItems[0].id, "#first-list");
    const target = rowSelector(secondItems[1].id, "#second-list");
    assertDragReady(assert, source, target);
    assertDragRegistered(`${source} .d-reorderable-list__handle`, target);
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
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            as |item|
          ><span
              data-test-item={{item.name}}
            >{{item.name}}</span></DReorderableList>
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
        <DReorderableList
          @items={{items}}
          @key={{indexKey}}
          @label={{label}}
          @onMove={{noop}}
          as |item|
        ><span data-test-item={{item}}>{{item}}</span></DReorderableList>
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
        <DReorderableList
          @items={{state.items}}
          @label={{label}}
          @onMove={{noop}}
          as |item|
        ><span
            data-test-item={{item.id}}
          >{{item.name}}</span></DReorderableList>
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
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @controls="manual"
          >
            <:default as |item row|>
              <span class="row-content" data-test-item={{item.id}}>
                {{item.name}}
              </span>
              {{#if row.arrows}}
                <div class="consumer-control-cell"><row.arrows /></div>
              {{/if}}
            </:default>
          </DReorderableList>
        </template>
      );

      assert
        .dom(".d-reorderable-list__row > .d-reorderable-list__handle")
        .doesNotExist("manual mode inserts no handle beside the row block");
      assert
        .dom(".d-reorderable-list__row > .d-reorderable-list__arrows")
        .doesNotExist("manual mode inserts no arrow pair beside the row block");
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
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @controls="manual"
            @movable={{movable}}
            id="manual-api"
          >
            <:default as |item row|>
              <span
                data-test-item={{item.id}}
                data-handle={{if row.handle "true" "false"}}
                data-arrows={{if row.arrows "true" "false"}}
                data-controls={{if row.controls "true" "false"}}
              >{{item.name}}</span>
              {{#if row.arrows}}<row.arrows />{{/if}}
            </:default>
          </DReorderableList>

          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @controls="start"
            id="start-api"
          >
            <:default as |item row|><span
                data-test-item={{item.id}}
                data-handle={{if row.handle "true" "false"}}
                data-arrows={{if row.arrows "true" "false"}}
                data-controls={{if row.controls "true" "false"}}
              >{{item.name}}</span></:default>
          </DReorderableList>

          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @controls="end"
            id="end-api"
          >
            <:default as |item row|><span
                data-test-item={{item.id}}
                data-handle={{if row.handle "true" "false"}}
                data-arrows={{if row.arrows "true" "false"}}
                data-controls={{if row.controls "true" "false"}}
              >{{item.name}}</span></:default>
          </DReorderableList>
        </template>
      );

      assert
        .dom(`${rowSelector(items[0].id, "#manual-api")} [data-test-item]`)
        .hasAttribute(
          "data-handle",
          "true",
          "a movable manual row yields a handle"
        )
        .hasAttribute(
          "data-arrows",
          "true",
          "a movable manual row yields arrows"
        )
        .hasAttribute(
          "data-controls",
          "true",
          "a movable manual row yields fused controls"
        );
      assert
        .dom(`${rowSelector(items[1].id, "#manual-api")} [data-test-item]`)
        .hasAttribute(
          "data-handle",
          "false",
          "a frozen manual row yields no handle"
        )
        .hasAttribute(
          "data-arrows",
          "false",
          "a frozen manual row yields no arrows"
        )
        .hasAttribute(
          "data-controls",
          "false",
          "a frozen manual row yields no fused controls"
        );

      for (const root of ["#start-api", "#end-api"]) {
        assert
          .dom(`${root} [data-test-item]`)
          .hasAttribute(
            "data-handle",
            "false",
            `${root} rows do not yield a manual handle`
          )
          .hasAttribute(
            "data-arrows",
            "false",
            `${root} rows do not yield manual arrows`
          )
          .hasAttribute(
            "data-controls",
            "false",
            `${root} rows do not yield fused manual controls`
          );
      }
    });

    test("manually placed handle and arrows match automatic controls", async function (assert) {
      const items = objectItems();

      await render(
        <template>
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @controls="manual"
            @arrowsLayout="inline"
          >
            <:default as |item row|>
              <div class="consumer-cell" data-test-item={{item.id}}>
                <row.handle
                  class="consumer-handle"
                  role="presentation"
                  data-consumer-handle={{item.id}}
                />
                <row.arrows
                  class="consumer-arrows"
                  role="group"
                  data-consumer-arrows={{item.id}}
                />
              </div>
            </:default>
          </DReorderableList>
        </template>
      );

      assert
        .dom(".consumer-cell > .d-reorderable-list__handle")
        .exists(
          { count: items.length },
          "one manually placed handle renders inside each nested cell"
        );
      assert
        .dom(".consumer-cell > .d-reorderable-list__arrows")
        .exists(
          { count: items.length },
          "one manually placed arrow pair renders inside each nested cell"
        );

      for (const [index, item] of items.entries()) {
        const row = rowSelector(item.id);
        const itemLabel = label(item);

        assert
          .dom(`${row} .consumer-handle`)
          .hasTagName("span", `${itemLabel}'s manual handle keeps its element`)
          .hasClass(
            "d-drag-handle",
            `${itemLabel}'s manual handle uses DDragHandle`
          )
          .hasClass(
            "d-reorderable-list__handle",
            `${itemLabel}'s manual handle keeps the list class`
          )
          .hasAttribute(
            "aria-hidden",
            "true",
            `${itemLabel}'s manual handle stays decorative`
          )
          .hasAttribute(
            "title",
            `Drag ${itemLabel}`,
            `${itemLabel}'s manual handle uses the standard translated label`
          )
          .hasAttribute(
            "role",
            "presentation",
            `${itemLabel}'s consumer handle role passes through`
          )
          .hasAttribute(
            "data-consumer-handle",
            item.id,
            `${itemLabel}'s consumer handle attribute passes through`
          );
        assert
          .dom(`${row} .consumer-arrows`)
          .hasTagName("span", `${itemLabel}'s manual arrows keep their element`)
          .hasClass(
            "d-reorder-buttons",
            `${itemLabel}'s manual arrows use DReorderButtons`
          )
          .hasClass(
            "d-reorderable-list__arrows",
            `${itemLabel}'s manual arrows keep the list class`
          )
          .hasClass(
            "--inline",
            `${itemLabel}'s manual arrows inherit the layout`
          )
          .hasAttribute(
            "role",
            "group",
            `${itemLabel}'s consumer arrow role passes through`
          )
          .hasAttribute(
            "data-consumer-arrows",
            item.id,
            `${itemLabel}'s consumer arrow attribute passes through`
          );
        assert
          .dom(arrowSelector(item.id, "up"))
          .hasTagName("button", `${itemLabel}'s manual up control is a button`)
          .hasAria(
            "label",
            `Move ${itemLabel} up`,
            `${itemLabel}'s manual up arrow uses the standard label`
          );
        assert
          .dom(arrowSelector(item.id, "down"))
          .hasTagName(
            "button",
            `${itemLabel}'s manual down control is a button`
          )
          .hasAria(
            "label",
            `Move ${itemLabel} down`,
            `${itemLabel}'s manual down arrow uses the standard label`
          );

        if (index === 0) {
          assert
            .dom(arrowSelector(item.id, "up"))
            .hasAttribute(
              "aria-disabled",
              "true",
              `${itemLabel}'s manual up arrow reflects the first boundary`
            );
        } else {
          assert
            .dom(arrowSelector(item.id, "up"))
            .doesNotHaveAttribute(
              "aria-disabled",
              `${itemLabel}'s manual up arrow is enabled away from the boundary`
            );
        }

        if (index === items.length - 1) {
          assert
            .dom(arrowSelector(item.id, "down"))
            .hasAttribute(
              "aria-disabled",
              "true",
              `${itemLabel}'s manual down arrow reflects the last boundary`
            );
        } else {
          assert
            .dom(arrowSelector(item.id, "down"))
            .doesNotHaveAttribute(
              "aria-disabled",
              `${itemLabel}'s manual down arrow is enabled away from the boundary`
            );
        }
      }
    });

    test("manual fused controls render handle then arrows", async function (assert) {
      const items = objectItems().slice(0, 1);

      await render(
        <template>
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @controls="manual"
            as |item row|
          >
            <div class="consumer-controls-cell" data-test-item={{item.id}}>
              <row.controls />
            </div>
          </DReorderableList>
        </template>
      );

      assert.deepEqual(
        Array.from(find(".consumer-controls-cell").children).map(
          (element) => element.className
        ),
        [
          "d-drag-handle d-reorderable-list__handle",
          "d-reorder-buttons d-reorderable-list__arrows",
        ],
        "the fused component renders the standard handle then the standard arrows"
      );
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
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{onMove}}
            @controls="manual"
          >
            <:default as |item row|>
              <div data-test-item={{item.id}}>
                <span class="consumer-handle-cell"><row.handle /></span>
                <span class="consumer-arrows-cell"><row.arrows /></span>
              </div>
            </:default>
          </DReorderableList>
        </template>
      );

      const source = rowSelector(sourceItem.id);
      const target = rowSelector(targetItem.id);
      assertDragRegistered(`${source} .d-reorderable-list__handle`, target);
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

    test("arrows-only manual surface commits and announces without asserting", async function (assert) {
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
            <DReorderableList
              @items={{items}}
              @key="id"
              @label={{label}}
              @onMove={{onMove}}
              @controls="manual"
              as |item row|
            >
              <div data-test-item={{item.id}}><row.arrows /></div>
            </DReorderableList>
          </template>
        );

        await click(assertArrowReady(assert, movedItem.id, "up"));
      } finally {
        resetOnerror();
      }

      assert.strictEqual(
        raised,
        undefined,
        "arrows alone satisfy the keyboard guard"
      );
      assert
        .dom(".d-reorderable-list__handle")
        .doesNotExist("an arrows-only surface needs no drag handle");
      assert.strictEqual(
        moves.length,
        1,
        "one manual arrow press commits once"
      );
      assert.deepEqual(
        moves[0],
        {
          method: "buttons",
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

    test("manual mode asserts when a movable row omits keyboard controls", async function (assert) {
      const items = objectItems().slice(0, 1);
      let raised;

      setupOnerror((error) => {
        raised = error;
      });

      try {
        await render(
          <template>
            <DReorderableList
              @items={{items}}
              @key="id"
              @label={{label}}
              @onMove={{noop}}
              @controls="manual"
              as |item row|
            >
              <span data-test-item={{item.id}}>{{item.name}}</span>
              {{#if row.handle}}<row.handle />{{/if}}
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
        /Assertion Failed:.*(arrow|keyboard|control)/i.test(
          raised?.message ?? ""
        ),
        "a handle-only movable row triggers the manual keyboard-path assertion"
      );
    });

    test("allowCreate renders the default create row between rows and static content", async function (assert) {
      const items = objectItems().slice(0, 2);
      const accessibleName = await loadAccessibleName();

      await render(
        <template>
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @onCreate={{noop}}
            @allowCreate={{true}}
          >
            <:default as |item|><span
                data-test-item={{item.id}}
              >{{item.name}}</span></:default>
            <:static><li data-slot="static">Static</li></:static>
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
        [...items.map((item) => item.id), "create", "static"],
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
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @onCreate={{onCreate}}
            @allowCreate={{true}}
            as |item|
          >
            <span data-test-item={{item.id}}>{{item.name}}</span>
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
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @onCreate={{onCreate}}
            @allowCreate={{true}}
            as |item|
          >
            <span data-test-item={{item.id}}>{{item.name}}</span>
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
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @onCreate={{noop}}
            as |item|
          >
            <span data-test-item={{item.id}}>{{item.name}}</span>
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
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @onCreate={{noop}}
            @allowCreate={{true}}
          >
            <:default as |item|><span
                data-test-item={{item.id}}
              >{{item.name}}</span></:default>
            <:create><li data-slot="create">Consumer create</li></:create>
            <:static><li data-slot="static">Static</li></:static>
          </DReorderableList>
        </template>
      );

      assert.deepEqual(
        Array.from(find(".d-reorderable-list").children).map(
          (element) => element.dataset.reorderableKey ?? element.dataset.slot
        ),
        [items[0].id, "create", "static"],
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
          <DReorderableList
            @items={{items}}
            @label={{label}}
            @onMove={{noop}}
            @onCreate={{noop}}
            @allowCreate={{true}}
          >
            <:default as |item|><span
                data-test-item={{item}}
              >{{item}}</span></:default>
            <:empty><li data-slot="empty">Nothing here</li></:empty>
            <:static><li data-slot="static">Static</li></:static>
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
        ["empty", "create", "static"],
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
          <DReorderableList
            @items={{state.items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
          >
            <:default as |item row|><span
                data-test-item={{item.id}}
                data-dragging={{if row.isDragging "true" "false"}}
              >{{item.name}}</span></:default>
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
        .dom(`[data-test-item="${draggedItem.id}"]`)
        .hasAttribute(
          "data-dragging",
          "true",
          "the source enters the dragging state"
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
        .dom(`[data-test-item="${draggedItem.id}"]`)
        .hasAttribute(
          "data-dragging",
          "false",
          "a reinserted row does not inherit its removed drag's key state"
        );
    });
  }
);

module("Integration | ui-kit | DReorderableList | group", function (hooks) {
  setupRenderingTest(hooks);

  test("DReorderableListGroup renders no wrapper around its block", async function (assert) {
    await render(
      <template>
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

  test("DReorderableList requires listId when it joins a group", async function (assert) {
    const items = objectItems().slice(0, 1);
    let raised;

    setupOnerror((error) => {
      raised = error;
    });

    try {
      await render(
        <template>
          <DReorderableListGroup @onMove={{noop}} as |group|>
            <DReorderableList
              @group={{group}}
              @items={{items}}
              @key="id"
              @label={{label}}
              as |item|
            >
              <span data-test-item={{item.id}}>{{item.name}}</span>
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

  test("DReorderableList routes an in-list button move through the group", async function (assert) {
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
          <DReorderableListGroup @onMove={{onMove}} as |group|>
            <DReorderableList
              @group={{group}}
              @listId="primary"
              @listLabel="Primary links"
              @items={{primaryItems}}
              @key="id"
              @label={{label}}
              id="button-primary-list"
              as |item|
            >
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </DReorderableList>
            <DReorderableList
              @group={{group}}
              @listId="secondary"
              @items={{secondaryItems}}
              @key="id"
              @label={{label}}
              id="button-secondary-list"
              as |item|
            >
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );

      const up = arrowSelector(movedItem.id, "up", "#button-primary-list");
      assert
        .dom(up)
        .exists("the grouped member arrow renders for the interaction");
      await click(up);
    } finally {
      resetOnerror();
    }

    assert.strictEqual(
      raised,
      undefined,
      "the grouped button move raises no error"
    );

    assert.strictEqual(
      onMove.callCount,
      1,
      "one member arrow press calls the group callback exactly once"
    );
    assert.deepEqual(
      onMove.firstCall.args[0],
      {
        method: "buttons",
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
      "the grouped button path keeps the standalone payload shape with member IDs"
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
          <DReorderableListGroup @onMove={{onMove}} as |group|>
            <DReorderableList
              @group={{group}}
              @listId="primary"
              @items={{primaryItems}}
              @key="id"
              @label={{label}}
              id="drag-primary-list"
              as |item|
            >
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </DReorderableList>
            <DReorderableList
              @group={{group}}
              @listId="secondary"
              @items={{secondaryItems}}
              @key="id"
              @label={{label}}
              id="drag-secondary-list"
              as |item|
            >
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );

      const source = rowSelector(movedItem.id, "#drag-primary-list");
      const target = rowSelector(targetItem.id, "#drag-primary-list");
      assertDragReady(assert, source, target);
      assertDragRegistered(`${source} .d-reorderable-list__handle`, target);
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
            as |item|
          >
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </DReorderableList>
          <DReorderableList
            @group={{group}}
            @listId="secondary"
            @listLabel="Secondary links"
            @items={{secondaryItems}}
            @key="id"
            @label={{label}}
            id="cross-secondary-list"
            as |item|
          >
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    const source = rowSelector(movedItem.id, "#cross-primary-list");
    const target = rowSelector(targetItem.id, "#cross-secondary-list");
    assertDragReady(assert, source, target);
    assertDragRegistered(`${source} .d-reorderable-list__handle`, target);
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

  test("DReorderableList keeps arrow boundaries within each group member", async function (assert) {
    const primaryItems = [{ id: "primary-alpha", name: "Primary Alpha" }];
    const secondaryItems = [
      { id: "secondary-alpha", name: "Secondary Alpha" },
      { id: "secondary-bravo", name: "Secondary Bravo" },
    ];
    const onMove = sinon.spy();
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DReorderableListGroup @onMove={{onMove}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="primary"
            @items={{primaryItems}}
            @key="id"
            @label={{label}}
            id="boundary-primary-list"
            as |item|
          >
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </DReorderableList>
          <DReorderableList
            @group={{group}}
            @listId="secondary"
            @items={{secondaryItems}}
            @key="id"
            @label={{label}}
            id="boundary-secondary-list"
            as |item|
          >
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    const up = arrowSelector(
      secondaryItems[0].id,
      "up",
      "#boundary-secondary-list"
    );
    assert
      .dom(up)
      .hasAttribute(
        "aria-disabled",
        "true",
        "the first row of the second member cannot move into the preceding member"
      );

    await click(up);

    assert.strictEqual(
      onMove.callCount,
      0,
      "pressing the local boundary arrow commits no group move"
    );
    assert.strictEqual(
      announce.callCount,
      0,
      "pressing the local boundary arrow makes no announcement"
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
        <DReorderableListGroup @onMove={{onMove}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="primary"
            @items={{primaryItems}}
            @key="id"
            @label={{label}}
            id="empty-source-list"
            as |item|
          >
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </DReorderableList>
          <DReorderableList
            @group={{group}}
            @listId="empty"
            @listLabel="Empty links"
            @items={{emptyItems}}
            @key="id"
            @label={{label}}
            id="empty-target-list"
            as |item|
          >
            <span data-test-item={{item.id}}>{{item.name}}</span>
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
    assertDragRegistered(`${source} .d-reorderable-list__handle`, target);
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
        <DReorderableListGroup @onMove={{noop}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="primary"
            @items={{primaryItems}}
            @key="id"
            @label={{label}}
            id="non-empty-primary-list"
            as |item|
          >
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </DReorderableList>
          <DReorderableList
            @group={{group}}
            @listId="secondary"
            @items={{secondaryItems}}
            @key="id"
            @label={{label}}
            id="non-empty-secondary-list"
            as |item|
          >
            <span data-test-item={{item.id}}>{{item.name}}</span>
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
        <DReorderableListGroup @onMove={{onMove}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="primary"
            @listLabel="Primary links"
            @items={{primaryItems}}
            @key="id"
            @label={{label}}
            id="unlabelled-primary-list"
            as |item|
          >
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </DReorderableList>
          <DReorderableList
            @group={{group}}
            @listId="secondary"
            @items={{secondaryItems}}
            @key="id"
            @label={{label}}
            id="unlabelled-secondary-list"
            as |item|
          >
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    const source = rowSelector(movedItem.id, "#unlabelled-primary-list");
    const target = rowSelector(targetItem.id, "#unlabelled-secondary-list");
    assertDragReady(assert, source, target);
    assertDragRegistered(`${source} .d-reorderable-list__handle`, target);
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
        <DReorderableListGroup @onMove={{groupOnMove}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="grouped"
            @items={{groupedItems}}
            @key="id"
            @label={{label}}
            id="isolated-grouped-list"
            as |item|
          >
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </DReorderableList>
        </DReorderableListGroup>
        <DReorderableList
          @items={{standaloneItems}}
          @key="id"
          @label={{label}}
          @onMove={{standaloneOnMove}}
          id="isolated-standalone-list"
          as |item|
        >
          <span data-test-item={{item.id}}>{{item.name}}</span>
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

    assertDragRegistered(
      `${groupedSource} .d-reorderable-list__handle`,
      standaloneTarget
    );
    await simulateDrag(groupedSource, standaloneTarget, {
      dataTransfer: new DataTransfer(),
      targetCoordinates: dropCoordinates(standaloneTarget, "before"),
    });

    assertDragRegistered(
      `${standaloneSource} .d-reorderable-list__handle`,
      groupedTarget
    );
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
        <DReorderableListGroup @onMove={{onMove}} as |group|>
          {{#if state.showPrimary}}
            <DReorderableList
              @group={{group}}
              @listId="primary"
              @items={{primaryItems}}
              @key="id"
              @label={{label}}
              id="teardown-primary-list"
              as |item|
            >
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </DReorderableList>
          {{/if}}
          <DReorderableList
            @group={{group}}
            @listId="secondary"
            @items={{secondaryItems}}
            @key="id"
            @label={{label}}
            id="teardown-secondary-list"
            as |item|
          >
            <span data-test-item={{item.id}}>{{item.name}}</span>
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
    assertDragRegistered(sourceHandle, target);
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
          <DReorderableListGroup @onMove={{noop}} as |group|>
            <DReorderableList
              @group={{group}}
              @listId="duplicate"
              @items={{primaryItems}}
              @key="id"
              @label={{label}}
              as |item|
            >
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </DReorderableList>
            <DReorderableList
              @group={{group}}
              @listId="duplicate"
              @items={{secondaryItems}}
              @key="id"
              @label={{label}}
              as |item|
            >
              <span data-test-item={{item.id}}>{{item.name}}</span>
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
