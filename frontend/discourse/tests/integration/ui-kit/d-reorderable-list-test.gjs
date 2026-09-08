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
import DMenus from "discourse/float-kit/components/d-menus";
import loadAccessibleName from "discourse/lib/load-accessible-name";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  centerOf,
  dragEvent,
  dragOver,
  simulateDrag,
  simulateUntargetedDrag,
  startDrag,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";
import {
  assertDragReady,
  dropCoordinates,
  label,
  List,
  MENU_SELECTOR,
  noop,
  objectItems,
  renderedItemOrder,
} from "discourse/tests/helpers/ui-kit/reorderable-list-fixtures";
import {
  handleSelector,
  moveItemSelector,
  moveVia,
  openMoveMenu,
  rowSelector,
} from "discourse/tests/helpers/ui-kit/reorderable-list-helper";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import DReorderableListGroup from "discourse/ui-kit/d-reorderable-list-group";

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
    const items = objectItems().slice(0, 2);

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

  test("lets a consumer choose the remove control's button weight", async function (assert) {
    const items = objectItems();
    const state = new (class {
      @tracked buttonClass;
    })();

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{items}}
          @key="id"
          @label={{label}}
          @onMove={{noop}}
          @onRemove={{noop}}
          @removeButtonClass={{state.buttonClass}}
        >
          <:row as |item|>
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </:row>
        </DReorderableList>
      </template>
    );

    assert
      .dom(".d-reorderable-list__remove")
      .hasClass("btn-flat", "falls back to a flat control");

    state.buttonClass = "btn-default";
    await settled();

    assert
      .dom(".d-reorderable-list__remove")
      .hasClass("btn-default", "takes the weight the consumer asked for");
    assert
      .dom(".d-reorderable-list__remove")
      .doesNotHaveClass(
        "btn-flat",
        "and drops the default rather than merging"
      );
  });

  test("offers only the reachable directions in the movable subsequence", async function (assert) {
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
      .doesNotExist("the first movable item cannot move up");
    assert
      .dom(moveItemSelector("down"))
      .exists("the first movable item can move down");
    await click(moveItemSelector("down"));

    await openMoveMenu(items[2].id);
    assert
      .dom(moveItemSelector("up"))
      .exists("the last movable item can move up");
    assert
      .dom(moveItemSelector("down"))
      .doesNotExist("the last movable item cannot move down");
  });

  test("menu moves emit the exact move payload and one default announcement", async function (assert) {
    const items = objectItems();
    const moves = [];
    const onMove = (move) => moves.push(move);
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template><List @items={{items}} @onMove={{onMove}} /></template>
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
      <template><List @items={{items}} @onMove={{onMove}} /></template>
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
      <template><List @items={{items}} @onMove={{onMove}} /></template>
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
      <template><List @items={{items}} @onMove={{onMove}} /></template>
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
      <template><List @items={{items}} @onMove={{onMove}} /></template>
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
      <template><List @items={{items}} @onMove={{onMove}} /></template>
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

    test("a lone movable row still yields a handle the consumer can render", async function (assert) {
      const items = [{ id: "alpha", name: "Alpha" }];

      await render(
        <template>
          <DMenus />
          <DReorderableList
            id="lone-manual"
            @controls="manual"
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
          >
            <:row as |item controls|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
              <controls.handle />
            </:row>
          </DReorderableList>
        </template>
      );

      assert
        .dom("#lone-manual [data-test-item]")
        .exists(
          "the row renders rather than the block failing on an absent control"
        );
      assert
        .dom("#lone-manual .d-reorderable-list__handle")
        .doesNotExist(
          "and the control draws nothing, because a lone row has nowhere to move"
        );
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

        const expectAbsent = {
          up: index === 0,
          down: index === items.length - 1,
        };
        for (const [target, absent] of Object.entries(expectAbsent)) {
          if (absent) {
            assert
              .dom(moveItemSelector(target))
              .doesNotExist(
                `${itemLabel}'s manual menu omits ${target} at the boundary`
              );
          } else {
            assert
              .dom(moveItemSelector(target))
              .exists(`${itemLabel}'s manual menu leaves ${target} available`);
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
      const items = objectItems().slice(0, 2);
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

module(
  "Integration | ui-kit | DReorderableList | rev42618 review oracle",
  function (hooks) {
    setupRenderingTest(hooks);

    test("rev42618 removal is judged by the row leaving not by the count", async function (assert) {
      const items = trackedArray(objectItems());
      const removed = items[1];
      const onRemove = (item) => {
        items.splice(items.indexOf(item), 1);
        items.push({ id: "delta", name: "Delta" });
      };
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

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

      await click(`${rowSelector(removed.id)} .d-reorderable-list__remove`);

      assert.false(
        renderedItemOrder().includes(removed.id),
        "the removed row is gone from the rendered order even though the count is unchanged"
      );
      assert.true(
        announce
          .getCalls()
          .some((call) => call.args[0].includes(label(removed))),
        "the removal is announced by the row leaving, naming the removed row, not inferred from the count"
      );
    });

    test("rev42618 focus after removal lands on the control that took the slot", async function (assert) {
      const items = trackedArray([
        { id: "alpha", name: "Alpha" },
        { id: "bravo", name: "Bravo" },
        { id: "charlie", name: "Charlie" },
        { id: "delta", name: "Delta" },
        { id: "echo", name: "Echo" },
      ]);
      const movable = (item) => item.id !== "alpha" && item.id !== "bravo";
      const onRemove = (item) => items.splice(items.indexOf(item), 1);

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @onRemove={{onRemove}}
            @movable={{movable}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      await click(`${rowSelector("charlie")} .d-reorderable-list__remove`);

      assert.strictEqual(
        document.activeElement,
        find(`${rowSelector("delta")} .d-reorderable-list__remove`),
        "focus lands on the remove control of the row that now occupies the vacated slot, not on the last row's control"
      );
    });

    test("rev42618 removing the last removable row keeps focus in the list", async function (assert) {
      const items = trackedArray([{ id: "alpha", name: "Alpha" }]);
      const onRemove = (item) => items.splice(items.indexOf(item), 1);

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @onRemove={{onRemove}}
            @onCreate={{noop}}
            @allowCreate={{true}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      await click(`${rowSelector("alpha")} .d-reorderable-list__remove`);

      assert.notStrictEqual(
        document.activeElement,
        document.body,
        "focus does not fall to the body when the last removable row goes"
      );
      assert.true(
        find(".d-reorderable-list").contains(document.activeElement),
        "focus stays inside the list root, where the reader can act again"
      );
    });

    test("rev42618 a row without a handle is not itself draggable", async function (assert) {
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

      assert
        .dom(handleSelector("alpha"))
        .doesNotExist(
          "a lone standalone row has nowhere to move, so it renders no handle"
        );
      assert.notStrictEqual(
        find(rowSelector("alpha")).getAttribute("draggable"),
        "true",
        "the drag source does not fall back to the row element, so the row's text stays selectable"
      );
    });

    test("rev42618 an open menu closes when its row leaves the list", async function (assert) {
      const items = trackedArray(objectItems());
      const removedKey = items[1].id;

      await render(
        <template><List @items={{items}} @onMove={{noop}} /></template>
      );

      await openMoveMenu(removedKey);
      assert
        .dom(MENU_SELECTOR)
        .exists("the move menu is open before the row leaves");

      const remaining = items.filter((item) => item.id !== removedKey);
      items.splice(0, items.length, ...remaining);
      await settled();

      assert
        .dom(MENU_SELECTOR)
        .doesNotExist(
          "the menu is dismissed when the row it describes leaves the list"
        );
    });

    test("rev42618 a lone grouped row advertises no popup", async function (assert) {
      const soloItems = [{ id: "golf", name: "Golf" }];
      const otherItems = [
        { id: "hotel", name: "Hotel" },
        { id: "india", name: "India" },
      ];

      await render(
        <template>
          <DMenus />
          <DReorderableListGroup @onMove={{noop}} as |group|>
            <DReorderableList
              @group={{group}}
              @listId="solo"
              @items={{soloItems}}
              @key="id"
              @label={{label}}
              id="solo-list"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
            <DReorderableList
              @group={{group}}
              @listId="other"
              @items={{otherItems}}
              @key="id"
              @label={{label}}
              id="other-list"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );

      assert
        .dom(handleSelector("golf", "#solo-list"))
        .exists(
          "the lone grouped row keeps its handle, which is still the cross-list drag source"
        );
      assert
        .dom(handleSelector("golf", "#solo-list"))
        .doesNotHaveAttribute(
          "aria-haspopup",
          "a handle whose menu holds no destinations advertises no popup"
        );

      await openMoveMenu("golf", "#solo-list");
      assert
        .dom(MENU_SELECTOR)
        .doesNotExist("clicking the handle opens no empty menu");
    });

    test("rev42618 the default create row is a cell in a table shell", async function (assert) {
      const items = objectItems().slice(0, 2);
      const onCreate = sinon.spy();

      await render(
        <template>
          <DMenus />
          {{! eslint-disable ember/template-table-groups }}
          <table>
            <DReorderableList
              @items={{items}}
              @key="id"
              @label={{label}}
              @onMove={{noop}}
              @onCreate={{onCreate}}
              @allowCreate={{true}}
              @tag="tbody"
              @itemTag="tr"
            >
              <:row as |item|>
                <td data-test-item={{item.id}}>{{item.name}}</td>
              </:row>
            </DReorderableList>
          </table>
        </template>
      );

      const createRow = find(".d-reorderable-list__create");
      assert
        .dom(createRow)
        .hasTagName("tr", "the create row adopts the table shell's item tag");
      const children = Array.from(createRow.children);
      assert.strictEqual(
        children.length,
        1,
        "the create row holds exactly one element child, so the tr contains no stray non-cell children"
      );
      assert
        .dom(children[0])
        .hasTagName("td", "that only child is a table cell");
      assert.true(
        !!children[0]?.querySelector(".d-reorderable-list__create-input"),
        "the create input lives inside the cell, keeping the table markup valid"
      );
    });

    test("rev42618 a standalone list without onMove asserts", async function (assert) {
      const items = objectItems();
      let raised;

      setupOnerror((error) => {
        raised = error;
      });

      try {
        await render(
          <template>
            <DMenus />
            <DReorderableList @items={{items}} @key="id" @label={{label}}>
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </template>
        );

        await moveVia(items[1].id, "up");
      } finally {
        resetOnerror();
      }

      assert.true(
        /Assertion Failed:.*@onMove/i.test(raised?.message ?? ""),
        "a standalone list has no way to commit a move without @onMove, and a development assertion says so"
      );
    });

    test("rev42618 a row refuses a drop on itself", async function (assert) {
      const items = objectItems();
      const onMove = sinon.spy();

      await render(
        <template><List @items={{items}} @onMove={{onMove}} /></template>
      );

      const source = rowSelector(items[1].id);
      assertDragReady(assert, source, source);

      const dataTransfer = new DataTransfer();
      await startDrag(source, { dataTransfer });
      await dragOver(source, {
        dataTransfer,
        coordinates: dropCoordinates(source, "before"),
      });

      assert
        .dom(source)
        .doesNotHaveClass(
          "--drag-above",
          "hovering a row with its own drag offers no before indicator"
        );
      assert
        .dom(source)
        .doesNotHaveClass(
          "--drag-below",
          "and no after indicator, so the row is never offered a position relative to itself"
        );

      await dragEvent(source, "drop", {
        dataTransfer,
        ...dropCoordinates(source, "before"),
      });
      const handle = handleSelector(items[1].id);
      await dragEvent(handle, "dragend", { dataTransfer, ...centerOf(handle) });

      assert.strictEqual(
        onMove.callCount,
        0,
        "a drop of a row on itself commits no move"
      );
    });

    test("rev42618 the hint block renders before the header", async function (assert) {
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
            <:hint><li data-slot="hint">Hint</li></:hint>
            <:header><li data-slot="header">Header</li></:header>
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      assert.dom("[data-slot='hint']").exists("the hint block renders");
      assert.dom("[data-slot='header']").exists("the header block renders");
      assert.deepEqual(
        Array.from(find(".d-reorderable-list").children).map(
          (element) => element.dataset.slot ?? element.dataset.reorderableKey
        ),
        ["hint", "header", ...items.map((item) => item.id)],
        "the hint precedes the header in document order, and both precede every row"
      );
    });

    test("rev42618 the move callback is read live", async function (assert) {
      const items = objectItems();
      const firstOnMove = sinon.spy();
      const secondOnMove = sinon.spy();
      const state = new (class {
        @tracked onMove = firstOnMove;
      })();

      await render(
        <template><List @items={{items}} @onMove={{state.onMove}} /></template>
      );

      state.onMove = secondOnMove;
      await settled();

      await moveVia(items[1].id, "up");

      assert.strictEqual(
        secondOnMove.callCount,
        1,
        "the callback swapped in after the first render receives the move"
      );
      assert.strictEqual(
        firstOnMove.callCount,
        0,
        "the callback captured at the first render does not, proving @onMove is read live"
      );
    });
  }
);
