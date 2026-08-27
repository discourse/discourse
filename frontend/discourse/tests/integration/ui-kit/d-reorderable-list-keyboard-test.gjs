import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { trackedArray } from "@ember/reactive/collections";
import {
  click,
  find,
  findAll,
  focus,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DialogHolder from "discourse/dialog-holder/components/dialog-holder";
import DMenus from "discourse/float-kit/components/d-menus";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  INDEX_KEY,
  isMovable,
  label,
  List,
  MENU_SELECTOR,
  mixedItems,
  noop,
  objectItems,
  renderedItemOrder,
} from "discourse/tests/helpers/ui-kit/reorderable-list-fixtures";
import {
  handleSelector,
  moveItemSelector,
  moveVia,
  moveViaChord,
  openMoveMenu,
  rowSelector,
} from "discourse/tests/helpers/ui-kit/reorderable-list-helper";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import DReorderableListGroup from "discourse/ui-kit/d-reorderable-list-group";

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
        <template><List @items={{items}} @onMove={{noop}} /></template>
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
        <template><List @items={{items}} @onMove={{noop}} /></template>
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
        <template><List @items={{items}} @onMove={{noop}} /></template>
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
        <template><List @items={{items}} @onMove={{noop}} /></template>
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
        <template><List @items={{items}} @onMove={{noop}} /></template>
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
        <template><List @items={{items}} @onMove={{handleMove}} /></template>
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
        <template><List @items={{items}} @onMove={{handleMove}} /></template>
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

    test("opening focuses the first destination the row can use", async function (assert) {
      // The first row can go nowhere but down, and the destinations it cannot
      // use are not in the menu to be focused in the first place.
      const items = objectItems();

      await render(
        <template><List @items={{items}} @onMove={{noop}} /></template>
      );

      await openMoveMenu("alpha");

      assert
        .dom(moveItemSelector("top"))
        .doesNotExist("the first row cannot go to the top");
      assert
        .dom(moveItemSelector("down"))
        .isFocused("so focus lands on the first destination it can use");
    });

    test("the menu is a menu, and its destinations are its items", async function (assert) {
      const items = objectItems();

      await render(
        <template><List @items={{items}} @onMove={{noop}} /></template>
      );

      assert
        .dom(handleSelector("alpha"))
        .hasAttribute(
          "aria-haspopup",
          "menu",
          "the handle says what it opens before it is opened"
        );

      await openMoveMenu("alpha");

      assert
        .dom(MENU_SELECTOR)
        .hasAttribute("role", "menu")
        .hasAttribute(
          "aria-label",
          "Reorder Alpha",
          "and the menu carries its trigger's name, so it is announced with the row it acts on"
        );
      assert
        .dom(moveItemSelector("down"))
        .hasAttribute("role", "menuitem", "each destination is an item of it");
    });

    test("arrows move between destinations, wrapping and skipping the refused", async function (assert) {
      const items = objectItems();

      await render(
        <template><List @items={{items}} @onMove={{noop}} /></template>
      );

      await openMoveMenu("bravo");
      assert
        .dom(moveItemSelector("top"))
        .isFocused("opening lands on the first");

      await triggerKeyEvent(moveItemSelector("top"), "keydown", "ArrowDown");
      assert.dom(moveItemSelector("up")).isFocused("ArrowDown steps forward");

      await triggerKeyEvent(moveItemSelector("up"), "keydown", "ArrowUp");
      assert.dom(moveItemSelector("top")).isFocused("ArrowUp steps back");

      await triggerKeyEvent(moveItemSelector("top"), "keydown", "End");
      assert.dom(moveItemSelector("bottom")).isFocused("End reaches the last");

      await triggerKeyEvent(moveItemSelector("bottom"), "keydown", "Home");
      assert
        .dom(moveItemSelector("top"))
        .isFocused("Home returns to the first");

      await triggerKeyEvent(moveItemSelector("top"), "keydown", "ArrowUp");
      assert
        .dom(moveItemSelector("bottom"))
        .isFocused("and the ends wrap rather than dead-ending");
    });

    test("the cursor steps over a destination the row cannot take", async function (assert) {
      const items = objectItems();

      await render(
        <template><List @items={{items}} @onMove={{noop}} /></template>
      );

      // The first row refuses both upward destinations, so wrapping backwards
      // from the first it can take has to clear them in one step.
      await openMoveMenu("alpha");
      assert.dom(moveItemSelector("down")).isFocused();

      await triggerKeyEvent(moveItemSelector("down"), "keydown", "ArrowUp");

      assert
        .dom(moveItemSelector("bottom"))
        .isFocused("the refused destinations are stepped over, not landed on");
    });

    test("an arrow inside the menu does not move the row cursor", async function (assert) {
      const items = objectItems();

      await render(
        <template><List @items={{items}} @onMove={{noop}} /></template>
      );

      await openMoveMenu("bravo");
      await triggerKeyEvent(moveItemSelector("top"), "keydown", "ArrowDown");

      assert
        .dom(moveItemSelector("up"))
        .isFocused("the arrow belongs to the menu it was pressed in");
      assert
        .dom(handleSelector("charlie"))
        .isNotFocused("and never reaches the row beneath");
    });

    test("Tab leaves the menu rather than cycling inside it", async function (assert) {
      const items = objectItems();

      await render(
        <template><List @items={{items}} @onMove={{noop}} /></template>
      );

      await openMoveMenu("bravo");
      assert.dom(moveItemSelector("top")).isFocused();

      await triggerKeyEvent(moveItemSelector("top"), "keydown", "Tab");

      // A non-modal float shows nothing to say that Tab has stopped meaning
      // "move on", so it dismisses and hands the sequence back where the reader
      // would have been had the menu never opened, rather than trapping them
      // with Escape as their only way out.
      assert
        .dom(".d-reorderable-list__move-item")
        .doesNotExist("Tab dismisses the menu");
      assert
        .dom(handleSelector("charlie"))
        .isFocused("and continues from the stop after the handle it opened at");

      await openMoveMenu("bravo");
      await triggerKeyEvent(moveItemSelector("top"), "keydown", "Tab", {
        shiftKey: true,
      });

      assert
        .dom(".d-reorderable-list__move-item")
        .doesNotExist("Shift+Tab dismisses it too");
      assert
        .dom(handleSelector("bravo"))
        .isFocused(
          "landing back on the handle, which is where the reader came in"
        );
    });

    test("the accelerator works from inside the menu it is advertised in", async function (assert) {
      const items = trackedArray(objectItems());
      const moves = [];
      const handleMove = (move) => {
        moves.push(move);
        items.splice(0, items.length, ...move.proposedToItems);
      };

      await render(
        <template><List @items={{items}} @onMove={{handleMove}} /></template>
      );

      await openMoveMenu("alpha");
      await triggerKeyEvent(moveItemSelector("down"), "keydown", "ArrowDown", {
        altKey: true,
      });

      assert.strictEqual(moves.length, 1, "the chord commits the same move");
      assert.deepEqual(renderedItemOrder(), ["bravo", "alpha", "charlie"]);
      assert
        .dom(".d-reorderable-list__move-item")
        .doesNotExist("and closes the menu, as choosing the destination would");
    });

    test("each destination shows and announces the accelerator it answers to", async function (assert) {
      const items = objectItems();
      const emptyItems = [];

      await render(
        <template>
          <DMenus />
          <DReorderableListGroup @onMove={{noop}} as |group|>
            <DReorderableList
              @group={{group}}
              @listId="primary"
              @listLabel="Primary"
              @items={{items}}
              @key="id"
              @label={{label}}
              id="hint-primary"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
            <DReorderableList
              @group={{group}}
              @listId="secondary"
              @listLabel="Secondary"
              @items={{emptyItems}}
              @key="id"
              @label={{label}}
              id="hint-secondary"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );

      await openMoveMenu("bravo", "#hint-primary");

      // Two forms, deliberately different. The drawn half carries the glyph
      // an arrow key shows on every platform, beside a spoken name for the
      // reader; the announced half carries the spoken name alone, because a
      // reader hearing the glyph learns nothing. Only the key half is
      // assertable: the modifier differs by keyboard.
      for (const [target, announced, drawn] of [
        ["top", /\+Home$/, "Home"],
        ["up", /\+Up arrow$/, "\u2191"],
        ["down", /\+Down arrow$/, "\u2193"],
        ["bottom", /\+End$/, "End"],
      ]) {
        assert
          .dom(moveItemSelector(target))
          .hasAttribute(
            "aria-keyshortcuts",
            announced,
            `${target} announces its accelerator by name`
          );
        assert
          .dom(`${moveItemSelector(target)} kbd`)
          .includesText(drawn, `${target} draws its key`);
      }

      // The raw event name is what a hand-rolled shortcut leaks; neither form
      // should ever carry it.
      assert
        .dom(`${moveItemSelector("up")} kbd`)
        .doesNotIncludeText(
          "ArrowUp",
          "the drawn form names the key for a reader, not for the event system"
        );

      assert
        .dom(moveItemSelector("list"))
        .doesNotHaveAttribute(
          "aria-keyshortcuts",
          "a cross-list destination has no accelerator to advertise"
        );
      assert
        .dom(`${moveItemSelector("list")} kbd`)
        .doesNotExist("so it shows nothing either");
    });

    test("a boundary row offers only the destinations that work", async function (assert) {
      const items = trackedArray(objectItems());
      const moves = [];
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
      const handleMove = (move) => moves.push(move);

      await render(
        <template><List @items={{items}} @onMove={{handleMove}} /></template>
      );

      await openMoveMenu("alpha");

      assert
        .dom(".d-reorderable-list__move-item")
        .exists(
          { count: 2 },
          "the first row is announced as holding only what it can reach"
        );
      for (const target of ["top", "up"]) {
        assert
          .dom(moveItemSelector(target))
          .doesNotExist(`${target} leads nowhere from the first row`);
      }
      for (const target of ["down", "bottom"]) {
        assert.dom(moveItemSelector(target)).exists(`${target} is available`);
      }

      await openMoveMenu("alpha");
      await openMoveMenu("bravo");

      assert
        .dom(".d-reorderable-list__move-item")
        .exists({ count: 4 }, "a row with room on both sides offers all four");

      await openMoveMenu("bravo");
      await openMoveMenu("charlie");

      assert
        .dom(".d-reorderable-list__move-item")
        .exists({ count: 2 }, "and the last row mirrors the first");
      for (const target of ["down", "bottom"]) {
        assert
          .dom(moveItemSelector(target))
          .doesNotExist(`${target} leads nowhere from the last row`);
      }

      await openMoveMenu("charlie");

      // The accelerator still reaches a boundary the menu no longer shows, so
      // the refusal is the only thing left to say it happened.
      await moveViaChord("alpha", "up");

      assert.deepEqual(moves, [], "a refused move commits nothing");
      assert.deepEqual(renderedItemOrder(), ["alpha", "bravo", "charlie"]);
      assert.true(
        announce.calledOnceWith("Alpha is already first"),
        "and the refusal is spoken rather than being a silent no-op"
      );
    });

    test("a row with nowhere to go renders no handle at all", async function (assert) {
      const items = [{ id: "alpha", name: "Alpha" }];

      await render(
        <template><List @items={{items}} @onMove={{noop}} /></template>
      );

      assert
        .dom(rowSelector("alpha"))
        .exists("the row is still rendered, it simply cannot be reordered");
      assert
        .dom(handleSelector("alpha"))
        .doesNotExist(
          "a lone row in a standalone list can be neither dragged nor moved, so it offers no control that would open onto nothing"
        );
    });

    test("a lone row keeps its handle where a sibling list is somewhere to go", async function (assert) {
      const items = [{ id: "alpha", name: "Alpha" }];
      const emptyItems = [];

      await render(
        <template>
          <DMenus />
          <DReorderableListGroup @onMove={{noop}} as |group|>
            <DReorderableList
              @group={{group}}
              @listId="primary"
              @listLabel="Primary"
              @items={{items}}
              @key="id"
              @label={{label}}
              id="lone-primary"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
            <DReorderableList
              @group={{group}}
              @listId="secondary"
              @listLabel="Secondary"
              @items={{emptyItems}}
              @key="id"
              @label={{label}}
              id="lone-secondary"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );

      assert
        .dom(handleSelector("alpha", "#lone-primary"))
        .exists("the sibling is a destination, so the handle has work to do");

      await openMoveMenu("alpha", "#lone-primary");

      assert
        .dom(".d-reorderable-list__move-item")
        .exists({ count: 1 }, "and the menu holds only that destination");
      assert
        .dom(moveItemSelector("list"))
        .exists("which is the sibling list, not a direction");
    });

    test("the arrow cursor reaches the rows a move cannot", async function (assert) {
      const items = trackedArray(mixedItems());

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @movable={{isMovable}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      find(handleSelector("bravo")).focus();
      await triggerKeyEvent(handleSelector("bravo"), "keydown", "ArrowDown");

      assert
        .dom(rowSelector("charlie"))
        .isFocused("the cursor carries on into a row that cannot be moved");

      await triggerKeyEvent(rowSelector("charlie"), "keydown", "ArrowDown");

      assert.dom(rowSelector("delta")).isFocused("and keeps going");

      await triggerKeyEvent(rowSelector("delta"), "keydown", "ArrowDown");

      assert
        .dom(rowSelector("delta"))
        .isFocused("clamping at the last row rather than wrapping");

      await triggerKeyEvent(rowSelector("delta"), "keydown", "ArrowUp");
      await triggerKeyEvent(rowSelector("charlie"), "keydown", "ArrowUp");

      assert
        .dom(handleSelector("bravo"))
        .isFocused("and hands back to the handle where a row renders one");
    });

    test("only a row with no handle becomes an arrow target", async function (assert) {
      const items = trackedArray(mixedItems());

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @movable={{isMovable}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      assert
        .dom(rowSelector("alpha"))
        .doesNotHaveAttribute(
          "tabindex",
          "a row whose handle is the cursor target stays out of the tab sequence itself"
        );
      assert
        .dom(rowSelector("charlie"))
        .hasAttribute(
          "tabindex",
          "-1",
          "a row with no handle is reachable by the cursor but never by Tab"
        );
    });

    test("a row's own field keeps the arrows its caret needs", async function (assert) {
      const items = trackedArray(mixedItems());

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @movable={{isMovable}}
          >
            <:row as |item|>
              <input id="field-{{item.id}}" value={{item.name}} />
            </:row>
          </DReorderableList>
        </template>
      );

      find("#field-alpha").focus();
      await triggerKeyEvent("#field-alpha", "keydown", "ArrowDown");

      assert
        .dom("#field-alpha")
        .isFocused(
          "a field is neither a handle nor a cursor row, so the list never claims its arrows"
        );
    });

    test("a control that cannot use an arrow lets the cursor step from its row", async function (assert) {
      const items = trackedArray(mixedItems());

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @movable={{isMovable}}
          >
            <:row as |item|>
              <button
                type="button"
                role="switch"
                aria-checked="false"
                id="switch-{{item.id}}"
              >{{item.name}}</button>
            </:row>
          </DReorderableList>
        </template>
      );

      find("#switch-charlie").focus();
      await triggerKeyEvent("#switch-charlie", "keydown", "ArrowDown");

      assert
        .dom(rowSelector("delta"))
        .isFocused(
          "a switch has no use for Up and Down, so the row it sits in answers for them"
        );

      await triggerKeyEvent(rowSelector("delta"), "keydown", "ArrowUp");

      assert
        .dom(rowSelector("charlie"))
        .isFocused("and the cursor is back on the row, not on the switch");
    });

    test("a control that does use the arrows keeps them", async function (assert) {
      const items = trackedArray(mixedItems());

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @movable={{isMovable}}
          >
            <:row as |item|>
              <button
                type="button"
                role="radio"
                aria-checked="false"
                id="radio-{{item.id}}"
              >{{item.name}}</button>
            </:row>
          </DReorderableList>
        </template>
      );

      find("#radio-charlie").focus();
      await triggerKeyEvent("#radio-charlie", "keydown", "ArrowDown");

      assert
        .dom("#radio-charlie")
        .isFocused(
          "the arrows move between radios in a group, so the list never claims them"
        );
    });

    test("an accelerator is refused on a row that cannot move", async function (assert) {
      const items = trackedArray(mixedItems());
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
            @movable={{isMovable}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      find(rowSelector("charlie")).focus();
      await triggerKeyEvent(rowSelector("charlie"), "keydown", "ArrowUp", {
        altKey: true,
      });

      assert.deepEqual(
        moves,
        [],
        "the chord belongs to the handle, and a frozen row has none"
      );
      assert.deepEqual(renderedItemOrder(), [
        "alpha",
        "bravo",
        "charlie",
        "delta",
      ]);
    });

    test("the arrow cursor steps over a target it cannot land on", async function (assert) {
      const items = trackedArray(mixedItems());

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            @movable={{isMovable}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      // Taken out of layout rather than out of the list, so the row is still a
      // selector match: exactly the case a raw querySelectorAll walk would hand
      // focus to.
      find(rowSelector("charlie")).style.display = "none";

      find(handleSelector("bravo")).focus();
      await triggerKeyEvent(handleSelector("bravo"), "keydown", "ArrowDown");

      assert
        .dom(rowSelector("delta"))
        .isFocused(
          "a row removed from layout is nowhere focus can be put, so the cursor passes it"
        );
    });

    test("a repeated chord carries the same row down an index-keyed list", async function (assert) {
      // Where the key is the position, refocusing by the key the row had before
      // the move lands on whichever row took that slot — so the next press
      // moves the wrong item and the two swap back and forth forever.
      const items = trackedArray(["Alpha", "Bravo", "Charlie"]);
      const indexKey = "@index";
      const handleMove = (move) => {
        items.splice(0, items.length, ...move.proposedToItems);
      };

      await render(
        <template>
          <DMenus />
          <DReorderableList
            @items={{items}}
            @key={{indexKey}}
            @label={{label}}
            @onMove={{handleMove}}
          >
            <:row as |item|>
              <span data-test-item={{item}}>{{item}}</span>
            </:row>
          </DReorderableList>
        </template>
      );

      await moveViaChord("0", "down");

      assert.deepEqual(renderedItemOrder(), ["Bravo", "Alpha", "Charlie"]);
      assert
        .dom(handleSelector("1"))
        .isFocused("focus follows the row that moved, not the slot it left");

      await triggerKeyEvent(handleSelector("1"), "keydown", "ArrowDown", {
        altKey: true,
      });

      assert.deepEqual(
        renderedItemOrder(),
        ["Bravo", "Charlie", "Alpha"],
        "so pressing again carries the same row further rather than swapping it back"
      );
      assert.dom(handleSelector("2")).isFocused();
    });

    test("Alt with an arrow moves the row and keeps focus on its handle", async function (assert) {
      const items = trackedArray(objectItems());
      const moves = [];
      const handleMove = (move) => {
        moves.push(move);
        items.splice(0, items.length, ...move.proposedToItems);
      };

      await render(
        <template><List @items={{items}} @onMove={{handleMove}} /></template>
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
        <template><List @items={{items}} @onMove={{handleMove}} /></template>
      );

      await moveViaChord("alpha", "bottom");
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
        <template><List @items={{items}} @onMove={{handleMove}} /></template>
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
        <template><List @items={{items}} @onMove={{handleMove}} /></template>
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
        <template><List @items={{items}} @onMove={{handleMove}} /></template>
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
        <template><List @items={{items}} @onMove={{noop}} /></template>
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
        <template><List @items={{items}} @onMove={{handleMove}} /></template>
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

    test("a removal that defers is not spoken for until it completes", async function (assert) {
      const state = new (class {
        @tracked items = objectItems();
      })();
      let release;
      const confirmed = new Promise((resolve) => (release = resolve));
      // What a consumer putting a confirmation in front of the removal returns:
      // the handler is back long before the reader has answered.
      const onRemove = (item) =>
        confirmed.then(() => {
          state.items = state.items.filter((candidate) => candidate !== item);
        });
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
        0,
        "nothing is announced while the row is still on screen"
      );
      assert.dom(rowSelector("bravo")).exists("and the row is still there");

      release();
      await settled();

      assert.dom(rowSelector("bravo")).doesNotExist("the row went");
      assert.strictEqual(
        announce.callCount,
        1,
        "and the announcement lands once it has"
      );
    });

    test("a removal behind a confirmation lands focus once the dialog has gone", async function (assert) {
      const state = new (class {
        @tracked items = objectItems();
      })();
      const dialog = this.owner.lookup("service:dialog");
      // Exactly the shape a consumer with a confirmation writes: the promise is
      // returned so the list waits, and the store is only touched on confirm.
      const onRemove = (item) =>
        dialog.yesNoConfirm({
          message: "Remove it?",
          didConfirm: () => {
            state.items = state.items.filter((candidate) => candidate !== item);
          },
        });
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

      await render(
        <template>
          <DMenus />
          <DialogHolder />
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
        0,
        "nothing is said while the reader is still being asked"
      );
      assert.dom(rowSelector("bravo")).exists("and the row is still there");

      await click(".dialog-footer .btn-primary");

      assert.dom(rowSelector("bravo")).doesNotExist("the row went");
      assert.strictEqual(
        announce.callCount,
        1,
        "and the removal is announced once it actually happened"
      );
      assert
        .dom(`${rowSelector("charlie")} .d-reorderable-list__remove`)
        .isFocused(
          "focus survives the dialog's teardown, so a reader clearing several rows is not thrown to the top of the page after each one"
        );
    });

    test("a cancelled confirmation leaves focus on the control that asked", async function (assert) {
      const items = trackedArray(objectItems());
      const dialog = this.owner.lookup("service:dialog");
      const onRemove = (item) =>
        dialog.yesNoConfirm({
          message: "Remove it?",
          didConfirm: () => items.splice(items.indexOf(item), 1),
        });

      await render(
        <template>
          <DMenus />
          <DialogHolder />
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

      const control = `${rowSelector("bravo")} .d-reorderable-list__remove`;
      await click(control);
      await click(".dialog-footer .btn-default");

      assert.dom(rowSelector("bravo")).exists("the row stayed");
      assert
        .dom(control)
        .isFocused(
          "the reader is put back where they were, since the confirmation hands focus to an element it has already detached"
        );
    });

    test("a removal the consumer declines is neither announced nor refocused", async function (assert) {
      const items = objectItems();
      // A handler that takes no action, which is every cancelled confirmation
      // and every refusal a consumer makes on its own terms.
      const onRemove = () => {};
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

      const control = `${rowSelector("bravo")} .d-reorderable-list__remove`;
      await click(control);

      assert.strictEqual(
        announce.callCount,
        0,
        "the list reports what happened, not what it asked for"
      );
      assert
        .dom(control)
        .isFocused("and leaves focus on the control that was pressed");
    });
  }
);
