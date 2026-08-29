import { tracked } from "@glimmer/tracking";
import { trackedArray } from "@ember/reactive/collections";
import { click, find, focus, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DMenus from "discourse/float-kit/components/d-menus";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
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
  openMoveMenu,
} from "discourse/tests/helpers/ui-kit/reorderable-list-helper";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import DReorderableListGroup from "discourse/ui-kit/d-reorderable-list-group";

module("Integration | ui-kit | DReorderableList | repairs", function (hooks) {
  setupRenderingTest(hooks);

  test("fix42618 a run that ends in a spill announces nothing about the list it left", async function (assert) {
    const upper = trackedArray([{ id: "golf", name: "Golf" }]);
    const lower = trackedArray([
      { id: "alpha", name: "Alpha" },
      { id: "bravo", name: "Bravo" },
    ]);
    // Both lists apply their moves for real, so the DOM reflects reality and
    // the settle timer reads the rows a reader would actually be looking at.
    const applyMove = (move) => {
      const listFor = (id) => (id === "upper" ? upper : lower);
      const from = listFor(move.fromList);
      from.splice(0, from.length, ...move.proposedFromItems);
      if (move.toList !== move.fromList) {
        const to = listFor(move.toList);
        to.splice(0, to.length, ...move.proposedToItems);
      }
    };
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{applyMove}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="upper"
            @listLabel="Upper"
            @spill={{true}}
            @items={{upper}}
            @key="id"
            @label={{label}}
            id="repair-spill-upper"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
          <DReorderableList
            @group={{group}}
            @listId="lower"
            @listLabel="Lower"
            @spill={{true}}
            @items={{lower}}
            @key="id"
            @label={{label}}
            id="repair-spill-lower"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    // Dispatched directly, and both in one turn: `triggerKeyEvent` awaits
    // `settled()`, which drains the run's settle timer and would end the run
    // between the two presses. A held key repeats far faster than that.
    const press = () =>
      document.activeElement.dispatchEvent(
        new KeyboardEvent("keydown", {
          key: "ArrowUp",
          altKey: true,
          bubbles: true,
        })
      );
    find(handleSelector("bravo", "#repair-spill-lower")).focus();
    press();
    press();
    await settled();

    assert.deepEqual(
      renderedItemOrder("#repair-spill-lower"),
      ["alpha"],
      "the first press committed in-list and the second hit the top boundary and spilled the row out"
    );
    assert.deepEqual(
      renderedItemOrder("#repair-spill-upper"),
      ["golf", "bravo"],
      "landing it on the tail of the member above, still travelling upwards"
    );
    for (const call of announce.getCalls()) {
      assert.false(
        String(call.args[0]).includes("Alpha"),
        `"${call.args[0]}" never mentions Alpha, the row that stayed behind: the settle sentence must speak for the row that travelled, not for whichever row now occupies the run's remembered index in the list it left`
      );
    }
  });

  test("fix42618 a custom announcer speaks once per chord press", async function (assert) {
    const items = trackedArray(objectItems());
    // Rendered directly rather than through the shared List fixture, which
    // does not forward @announceMove.
    const customSentence = () => "Custom sentence";
    const handleMove = (move) => {
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
          @announceMove={{customSentence}}
          @onMove={{handleMove}}
        >
          <:row as |item|>
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </:row>
        </DReorderableList>
      </template>
    );

    // Dispatched directly, then settled: `settled()` drains the run's settle
    // timer, which is where the duplicate custom sentence comes from.
    find(handleSelector("alpha")).focus();
    document.activeElement.dispatchEvent(
      new KeyboardEvent("keydown", {
        key: "ArrowDown",
        altKey: true,
        bubbles: true,
      })
    );
    await settled();

    assert.strictEqual(
      announce.callCount,
      1,
      "one press is one sentence: the custom announcer fires at commit or at settle but never both, so the reader does not hear the same sentence twice"
    );
    assert.strictEqual(
      announce.firstCall.args[0],
      "Custom sentence",
      "and the one sentence spoken is the consumer's own"
    );
  });

  test("fix42618 an unapplied move is not announced at settle", async function (assert) {
    const items = objectItems();
    const moves = [];
    // Records but neither applies nor returns false: the shape of a handler
    // awaiting a server round trip that outlasts the settle window.
    const handleMove = (move) => {
      moves.push(move);
    };
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template><List @items={{items}} @onMove={{handleMove}} /></template>
    );

    // Dispatched directly, then settled: `settled()` drains the run's settle
    // timer, which must not speak for a move the DOM never showed.
    find(handleSelector("alpha")).focus();
    document.activeElement.dispatchEvent(
      new KeyboardEvent("keydown", {
        key: "ArrowDown",
        altKey: true,
        bubbles: true,
      })
    );
    await settled();

    assert.strictEqual(
      moves.length,
      1,
      "the move was dispatched to the consumer"
    );
    assert.deepEqual(
      renderedItemOrder(),
      ["alpha", "bravo", "charlie"],
      "but never applied, so the rendered order is unchanged"
    );
    for (const call of announce.getCalls()) {
      assert.false(
        String(call.args[0]).includes("Bravo"),
        `"${call.args[0]}" never names Bravo, the row that merely sat at the landing slot: settling on an unapplied move must be silence, not a sentence about a row that did not move`
      );
    }
  });

  test("fix42618 a handle whose destinations vanished still closes its own menu", async function (assert) {
    const soloItems = [{ id: "solo", name: "Solo" }];
    const partnerItems = [{ id: "partner-alpha", name: "Partner Alpha" }];
    const state = new (class {
      @tracked showPartner = true;
    })();

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{noop}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="solo"
            @listLabel="Solo"
            @items={{soloItems}}
            @key="id"
            @label={{label}}
            id="repair-vanish-solo"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
          {{#if state.showPartner}}
            <DReorderableList
              @group={{group}}
              @listId="partner"
              @listLabel="Partner"
              @items={{partnerItems}}
              @key="id"
              @label={{label}}
              id="repair-vanish-partner"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          {{/if}}
        </DReorderableListGroup>
      </template>
    );

    await openMoveMenu("solo", "#repair-vanish-solo");

    assert
      .dom(moveItemSelector("list"))
      .exists(
        "the sibling is a destination while it is mounted, so the menu opens holding it"
      );

    state.showPartner = false;
    await settled();

    assert
      .dom("#repair-vanish-partner")
      .doesNotExist(
        "the sibling unmounted while the menu was still open, taking the only destination with it"
      );

    await click(handleSelector("solo", "#repair-vanish-solo"));

    assert
      .dom(MENU_SELECTOR)
      .doesNotExist(
        "pressing the trigger of an open menu closes it even when every destination has since vanished: the empty-destination guard must not make the toggle inert and strand the menu open"
      );
  });

  test("fix42618 a modified arrow keeps its browser meaning", async function (assert) {
    const items = objectItems();

    await render(
      <template><List @items={{items}} @onMove={{noop}} /></template>
    );

    // Constructed by hand because `triggerKeyEvent` never hands the event
    // back, and `defaultPrevented` is the whole assertion.
    await focus(handleSelector("alpha"));
    const modified = new KeyboardEvent("keydown", {
      key: "ArrowUp",
      bubbles: true,
      cancelable: true,
      metaKey: true,
    });
    find(handleSelector("alpha")).dispatchEvent(modified);
    await settled();

    assert.false(
      modified.defaultPrevented,
      "a meta-modified arrow is a browser shortcut rather than a cursor move, so the list must let it pass instead of swallowing it"
    );

    const bare = new KeyboardEvent("keydown", {
      key: "ArrowUp",
      bubbles: true,
      cancelable: true,
    });
    find(handleSelector("alpha")).dispatchEvent(bare);
    await settled();

    assert.true(
      bare.defaultPrevented,
      "while an unmodified ArrowUp on that same first handle is still consumed, so reclaiming the modified form does not regress the bare cursor arrows"
    );
  });
  test("fix42618 a drag-only handle does not promise a keyboard menu", async function (assert) {
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

    const handle = find(handleSelector("golf", "#solo-list"));
    assert.dom(handle).exists("the lone grouped row keeps its drag handle");

    const describedBy = handle.getAttribute("aria-describedby");
    const description = describedBy ? find(`#${describedBy}`) : null;
    const spoken = description ? description.textContent.trim() : "";
    assert.false(
      spoken.includes("Enter"),
      "a handle that opens no menu does not tell a screen reader to press Enter for move options"
    );
    assert
      .dom(handle)
      .hasAria("label", "Reorder Golf", "and it keeps its name");
  });
});
