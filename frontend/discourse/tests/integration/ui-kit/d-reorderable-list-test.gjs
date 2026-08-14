import { tracked } from "@glimmer/tracking";
import { trackedArray } from "@ember/reactive/collections";
import {
  click,
  find,
  findAll,
  render,
  resetOnerror,
  settled,
  setupOnerror,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  assertDragRegistered,
  centerOf,
  dragEvent,
  simulateDrag,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";

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
