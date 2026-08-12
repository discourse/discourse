import { findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";

module(
  "Integration | ui-kit | Modifier | dRovingFocus | api",
  function (hooks) {
    setupRenderingTest(hooks);

    test("rovingApi: focusNext seeds the first navigable item when no cursor exists", async function (assert) {
      let api = null;
      const changes = [];
      const boundaries = [];
      const register = (value) => (api = value);
      const onActiveChange = (item) => changes.push(item);
      const onBoundary = (direction, axis) =>
        boundaries.push(`${axis}:${direction}`);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="horizontal"
              itemSelector="[role=option]"
              tabStop=false
              onRegisterApi=register
              onActiveChange=onActiveChange
              onBoundary=onBoundary
            }}
          >
            <button class="item" role="option">A</button>
            <button class="item" role="option" style="display: none;">B</button>
            <button class="item" role="option">C</button>
          </div>
        </template>
      );

      const navigableItems = findAll(".item:not([style])");
      assert.strictEqual(
        api.focusNext(),
        "moved",
        "focusNext reports that it seeded a cursor"
      );
      assert
        .dom(navigableItems[0])
        .isFocused("focusNext seeds the first measured navigable item");
      assert.deepEqual(
        changes,
        [navigableItems[0]],
        "seeding through focusNext fires onActiveChange for the landed item"
      );
      assert.deepEqual(
        boundaries,
        [],
        "seeding through focusNext does not fire onBoundary"
      );
    });

    test("rovingApi: focusNext moves once then returns edge without firing callbacks", async function (assert) {
      let api = null;
      const changes = [];
      const boundaries = [];
      const register = (value) => (api = value);
      const onActiveChange = (item) => changes.push(item);
      const onBoundary = (direction, axis) =>
        boundaries.push(`${axis}:${direction}`);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="horizontal"
              itemSelector="[role=option]"
              onRegisterApi=register
              onActiveChange=onActiveChange
              onBoundary=onBoundary
            }}
          >
            <button class="item" role="option">A</button>
            <button class="item" role="option">B</button>
            <button class="item" role="option">C</button>
          </div>
        </template>
      );

      const items = findAll(".item");
      assert.true(
        api.focusIndex(0),
        "the existing api seeds the measured first item"
      );
      changes.length = 0;

      assert.strictEqual(
        api.focusNext(),
        "moved",
        "focusNext reports a real forward move"
      );
      assert
        .dom(items[1])
        .isFocused("focusNext advances to the next measured navigable item");
      assert.deepEqual(
        changes,
        [items[1]],
        "a real focusNext move fires onActiveChange exactly once"
      );

      assert.true(
        api.focusLast(),
        "the existing api places the cursor at the measured end"
      );
      changes.length = 0;
      assert.strictEqual(
        api.focusNext(),
        "edge",
        "focusNext distinguishes the end of an existing run from an unavailable group"
      );
      assert
        .dom(items[items.length - 1])
        .isFocused(
          "focusNext leaves the cursor on the measured last item at the edge"
        );
      assert.deepEqual(
        changes,
        [],
        "an edge result does not fire onActiveChange when nothing moved"
      );
      assert.deepEqual(boundaries, [], "an api edge suppresses onBoundary");
    });

    test("rovingApi: focusPrevious moves once then returns edge without firing callbacks", async function (assert) {
      let api = null;
      const changes = [];
      const boundaries = [];
      const register = (value) => (api = value);
      const onActiveChange = (item) => changes.push(item);
      const onBoundary = (direction, axis) =>
        boundaries.push(`${axis}:${direction}`);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="horizontal"
              itemSelector="[role=option]"
              onRegisterApi=register
              onActiveChange=onActiveChange
              onBoundary=onBoundary
            }}
          >
            <button class="item" role="option">A</button>
            <button class="item" role="option">B</button>
            <button class="item" role="option">C</button>
          </div>
        </template>
      );

      const items = findAll(".item");
      assert.true(
        api.focusIndex(items.length - 1),
        "the existing api seeds the measured last item"
      );
      changes.length = 0;

      assert.strictEqual(
        api.focusPrevious(),
        "moved",
        "focusPrevious reports a real backward move"
      );
      assert
        .dom(items[items.length - 2])
        .isFocused(
          "focusPrevious retreats to the previous measured navigable item"
        );
      assert.deepEqual(
        changes,
        [items[items.length - 2]],
        "a real focusPrevious move fires onActiveChange exactly once"
      );

      assert.true(
        api.focusFirst(),
        "the existing api places the cursor at the measured start"
      );
      changes.length = 0;
      assert.strictEqual(
        api.focusPrevious(),
        "edge",
        "focusPrevious distinguishes the start of an existing run from an unavailable group"
      );
      assert
        .dom(items[0])
        .isFocused(
          "focusPrevious leaves the cursor on the measured first item at the edge"
        );
      assert.deepEqual(
        changes,
        [],
        "a backward edge does not fire onActiveChange when nothing moved"
      );
      assert.deepEqual(
        boundaries,
        [],
        "a backward api edge suppresses onBoundary"
      );
    });

    test("rovingApi: focusNext returns unavailable for a group with no items", async function (assert) {
      let api = null;
      const boundaries = [];
      const register = (value) => (api = value);
      const onBoundary = (direction, axis) =>
        boundaries.push(`${axis}:${direction}`);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              itemSelector="[role=option]"
              onRegisterApi=register
              onBoundary=onBoundary
            }}
          ></div>
        </template>
      );

      assert.strictEqual(
        api.focusNext(),
        "unavailable",
        "focusNext reports that the group has no items to fall back from"
      );
      assert.deepEqual(
        boundaries,
        [],
        "an unavailable focusNext call does not fire onBoundary"
      );
    });

    test("rovingApi: focusPrevious returns unavailable for a group with no items", async function (assert) {
      let api = null;
      const boundaries = [];
      const register = (value) => (api = value);
      const onBoundary = (direction, axis) =>
        boundaries.push(`${axis}:${direction}`);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              itemSelector="[role=option]"
              onRegisterApi=register
              onBoundary=onBoundary
            }}
          ></div>
        </template>
      );

      assert.strictEqual(
        api.focusPrevious(),
        "unavailable",
        "focusPrevious reports that the group has no items to fall back from"
      );
      assert.deepEqual(
        boundaries,
        [],
        "an unavailable focusPrevious call does not fire onBoundary"
      );
    });

    test("rovingApi: focusNext returns unavailable when every layout cell is non-navigable", async function (assert) {
      let api = null;
      const boundaries = [];
      const register = (value) => (api = value);
      const onBoundary = (direction, axis) =>
        boundaries.push(`${axis}:${direction}`);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              itemSelector="[role=option]"
              onRegisterApi=register
              onBoundary=onBoundary
            }}
          >
            <button role="option" aria-disabled="true">ARIA disabled</button>
            <button role="option" disabled>Native disabled</button>
            <button
              role="option"
              style="visibility: hidden; width: 40px; height: 20px;"
            >Visibility hidden</button>
          </div>
        </template>
      );

      assert.deepEqual(
        api.items(),
        [],
        "items excludes every non-navigable layout cell"
      );
      assert.strictEqual(
        api.focusNext(),
        "unavailable",
        "focusNext reports that there is no navigable run to step through"
      );
      assert.strictEqual(
        api.currentItem(),
        null,
        "currentItem remains null when no navigable run exists"
      );
      assert.deepEqual(
        boundaries,
        [],
        "an unavailable focusNext call does not fire onBoundary"
      );
    });

    test("rovingApi: focusPrevious returns unavailable when every layout cell is non-navigable", async function (assert) {
      let api = null;
      const boundaries = [];
      const register = (value) => (api = value);
      const onBoundary = (direction, axis) =>
        boundaries.push(`${axis}:${direction}`);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              itemSelector="[role=option]"
              onRegisterApi=register
              onBoundary=onBoundary
            }}
          >
            <button role="option" aria-disabled="true">ARIA disabled</button>
            <button role="option" disabled>Native disabled</button>
            <button
              role="option"
              style="visibility: hidden; width: 40px; height: 20px;"
            >Visibility hidden</button>
          </div>
        </template>
      );

      assert.deepEqual(
        api.items(),
        [],
        "items excludes every non-navigable layout cell"
      );
      assert.strictEqual(
        api.focusPrevious(),
        "unavailable",
        "focusPrevious reports that there is no navigable run to step through"
      );
      assert.strictEqual(
        api.currentItem(),
        null,
        "currentItem remains null when no navigable run exists"
      );
      assert.deepEqual(
        boundaries,
        [],
        "an unavailable focusPrevious call does not fire onBoundary"
      );
    });

    test("rovingApi: a mixed group retains its navigable run", async function (assert) {
      let api = null;
      const register = (value) => (api = value);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              itemSelector="[role=option]"
              tabStop=false
              onRegisterApi=register
            }}
          >
            <button role="option" aria-disabled="true">ARIA disabled</button>
            <button class="navigable" role="option">Navigable</button>
            <button role="option" disabled>Native disabled</button>
            <button
              role="option"
              style="visibility: hidden; width: 40px; height: 20px;"
            >Visibility hidden</button>
          </div>
        </template>
      );

      const navigable = findAll(".navigable")[0];
      assert.deepEqual(
        api.items(),
        [navigable],
        "items retains the navigable match among non-navigable layout cells"
      );
      assert.strictEqual(
        api.focusNext(),
        "moved",
        "focusNext seeds the mixed group's navigable run"
      );
      assert.strictEqual(
        api.currentItem(),
        navigable,
        "currentItem reports the navigable member of the mixed group"
      );
      assert.strictEqual(
        api.focusNext(),
        "edge",
        "focusNext reports the end of the mixed group's navigable run"
      );
      assert.strictEqual(
        api.focusPrevious(),
        "edge",
        "focusPrevious reports the start of the mixed group's navigable run"
      );
    });

    test("rovingApi: focusNext honors horizontal and vertical axes in a grid", async function (assert) {
      let api = null;
      const boundaries = [];
      const register = (value) => (api = value);
      const onBoundary = (direction, axis) =>
        boundaries.push(`${axis}:${direction}`);

      await render(
        <template>
          <div
            role="listbox"
            style="display: grid; grid-template-columns: repeat(2, 40px);"
            {{dRovingFocus
              itemSelector="[role=option]"
              onRegisterApi=register
              onBoundary=onBoundary
            }}
          >
            <button
              class="cell"
              role="option"
              data-row="start"
              data-column="start"
            >A</button>
            <button
              class="cell"
              role="option"
              data-row="start"
              data-column="end"
            >B</button>
            <button
              class="cell"
              role="option"
              data-row="end"
              data-column="start"
            >C</button>
            <button
              class="cell"
              role="option"
              data-row="end"
              data-column="end"
            >D</button>
          </div>
        </template>
      );

      const cells = findAll(".cell");
      const start = cells.find(
        (item) =>
          item.dataset.row === "start" && item.dataset.column === "start"
      );
      const horizontalTarget = cells.find(
        (item) => item.dataset.row === "start" && item.dataset.column === "end"
      );
      const verticalTarget = cells.find(
        (item) => item.dataset.row === "end" && item.dataset.column === "start"
      );

      assert.true(
        api.focusIndex(cells.indexOf(start)),
        "the existing api seeds the measured grid origin"
      );
      assert.strictEqual(
        api.focusNext("horizontal"),
        "moved",
        "horizontal focusNext reports a move within the measured row"
      );
      assert
        .dom(horizontalTarget)
        .isFocused(
          "horizontal focusNext lands on the next cell in the same row"
        );
      assert.strictEqual(
        api.focusNext("horizontal"),
        "edge",
        "horizontal focusNext reports the row edge instead of drifting into the next row"
      );
      assert
        .dom(horizontalTarget)
        .isFocused(
          "the horizontal row edge leaves the cursor in its measured row"
        );

      assert.true(
        api.focusIndex(cells.indexOf(start)),
        "the existing api restores the measured grid origin"
      );
      assert.strictEqual(
        api.focusNext("vertical"),
        "moved",
        "vertical focusNext reports a move to the next measured row"
      );
      assert
        .dom(verticalTarget)
        .isFocused(
          "vertical focusNext lands in the same column of the next row"
        );
      assert.strictEqual(
        api.focusNext("vertical"),
        "edge",
        "vertical focusNext reports the measured bottom edge"
      );
      assert.deepEqual(
        boundaries,
        [],
        "grid focusNext api calls suppress onBoundary"
      );
      assert.deepEqual(
        boundaries,
        [],
        "grid focusNext api calls suppress onBoundary"
      );
    });

    test("rovingApi: focusPrevious honors horizontal and vertical axes in a grid", async function (assert) {
      let api = null;
      const boundaries = [];
      const register = (value) => (api = value);
      const onBoundary = (direction, axis) =>
        boundaries.push(`${axis}:${direction}`);

      await render(
        <template>
          <div
            role="listbox"
            style="display: grid; grid-template-columns: repeat(2, 40px);"
            {{dRovingFocus
              itemSelector="[role=option]"
              onRegisterApi=register
              onBoundary=onBoundary
            }}
          >
            <button
              class="cell"
              role="option"
              data-row="start"
              data-column="start"
            >A</button>
            <button
              class="cell"
              role="option"
              data-row="start"
              data-column="end"
            >B</button>
            <button
              class="cell"
              role="option"
              data-row="end"
              data-column="start"
            >C</button>
            <button
              class="cell"
              role="option"
              data-row="end"
              data-column="end"
            >D</button>
          </div>
        </template>
      );

      const cells = findAll(".cell");
      const start = cells.find(
        (item) => item.dataset.row === "end" && item.dataset.column === "end"
      );
      const horizontalTarget = cells.find(
        (item) => item.dataset.row === "end" && item.dataset.column === "start"
      );
      const verticalTarget = cells.find(
        (item) => item.dataset.row === "start" && item.dataset.column === "end"
      );

      assert.true(
        api.focusIndex(cells.indexOf(start)),
        "the existing api seeds the measured grid end"
      );
      assert.strictEqual(
        api.focusPrevious("horizontal"),
        "moved",
        "horizontal focusPrevious reports a move within the measured row"
      );
      assert
        .dom(horizontalTarget)
        .isFocused(
          "horizontal focusPrevious lands on the prior cell in the same row"
        );
      assert.strictEqual(
        api.focusPrevious("horizontal"),
        "edge",
        "horizontal focusPrevious reports the row edge instead of drifting into the prior row"
      );
      assert
        .dom(horizontalTarget)
        .isFocused(
          "the backward horizontal edge leaves the cursor in its measured row"
        );

      assert.true(
        api.focusIndex(cells.indexOf(start)),
        "the existing api restores the measured grid end"
      );
      assert.strictEqual(
        api.focusPrevious("vertical"),
        "moved",
        "vertical focusPrevious reports a move to the prior measured row"
      );
      assert
        .dom(verticalTarget)
        .isFocused(
          "vertical focusPrevious lands in the same column of the prior row"
        );
      assert.strictEqual(
        api.focusPrevious("vertical"),
        "edge",
        "vertical focusPrevious reports the measured top edge"
      );
      assert.deepEqual(
        boundaries,
        [],
        "grid focusPrevious api calls suppress onBoundary"
      );
    });

    test("rovingApi: currentItem is null before a cursor exists", async function (assert) {
      let api = null;
      const register = (value) => (api = value);

      await render(
        <template>
          <input class="controller" role="combobox" />
          <div
            role="listbox"
            {{dRovingFocus
              focusStrategy="active-descendant"
              entryFocus="none"
              controllerElement=".controller"
              itemSelector="[role=option]"
              onRegisterApi=register
            }}
          >
            <button role="option">A</button>
            <button role="option">B</button>
          </div>
        </template>
      );

      assert.strictEqual(
        api.currentItem(),
        null,
        "currentItem reports null before the modifier has placed a cursor"
      );
    });

    test("rovingApi: focusElement rejects an element outside the group without moving", async function (assert) {
      let api = null;
      const register = (value) => (api = value);

      await render(
        <template>
          <button class="outside" type="button">Outside</button>
          <div
            role="listbox"
            {{dRovingFocus itemSelector="[role=option]" onRegisterApi=register}}
          >
            <button class="item" role="option">A</button>
            <button class="item" role="option">B</button>
          </div>
        </template>
      );

      const groupItems = findAll(".item");
      const cursor = groupItems[groupItems.length - 1];
      const outside = findAll(".outside")[0];
      assert.true(
        api.focusIndex(groupItems.indexOf(cursor)),
        "the existing api places the cursor on a measured group member"
      );
      assert.false(
        api.focusElement(outside),
        "focusElement rejects an element outside the group"
      );
      assert
        .dom(cursor)
        .isFocused("a rejected outside element leaves DOM focus unchanged");
      assert.strictEqual(
        api.currentItem(),
        cursor,
        "a rejected outside element leaves the api cursor unchanged"
      );
    });

    test("rovingApi: element addressing round-trips every item in DOM order", async function (assert) {
      let api = null;
      const register = (value) => (api = value);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus itemSelector="[role=option]" onRegisterApi=register}}
          >
            <button class="item" role="option" data-label="alpha">A</button>
            <button class="item" role="option" data-label="beta">B</button>
            <button class="item" role="option" data-label="gamma">C</button>
          </div>
        </template>
      );

      const matchedItems = findAll(".item");
      const apiItems = api.items();
      assert.deepEqual(
        apiItems,
        matchedItems,
        "items returns the measured group items in DOM order when all are navigable"
      );

      apiItems.forEach((item, index) => {
        assert.strictEqual(
          api.indexOf(item),
          index,
          `indexOf maps the ${item.dataset.label} item back to its items position`
        );
        assert.true(
          api.focusElement(item),
          `focusElement accepts the ${item.dataset.label} item returned by items`
        );
        assert.strictEqual(
          api.currentItem(),
          item,
          `currentItem returns the exact ${item.dataset.label} element focused by address`
        );
        assert.strictEqual(
          api.indexOf(api.currentItem()),
          index,
          `the current ${item.dataset.label} element round-trips to the same index`
        );
      });

      const outside = document.createElement("button");
      assert.strictEqual(
        api.indexOf(outside),
        -1,
        "indexOf returns -1 for an element that is not a group member"
      );
    });

    test("rovingApi: element addressing does not drift across interleaved non-navigable matches", async function (assert) {
      let api = null;
      const register = (value) => (api = value);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus itemSelector="[role=option]" onRegisterApi=register}}
          >
            <button
              class="item navigable"
              role="option"
              data-label="alpha"
            >A</button>
            <button
              class="item hidden"
              role="option"
              style="display: none;"
              data-label="hidden-one"
            >Hidden one</button>
            <button
              class="item navigable"
              role="option"
              data-label="beta"
            >B</button>
            <button
              class="item hidden"
              role="option"
              style="visibility: hidden; width: 0; height: 0; padding: 0; border: 0;"
              data-label="hidden-zero-size"
            >Hidden zero size</button>
            <button
              class="item navigable"
              role="option"
              data-label="gamma"
            >C</button>
            <button
              class="item hidden"
              role="option"
              style="display: none;"
              data-label="hidden-two"
            >Hidden two</button>
            <button
              class="item navigable"
              role="option"
              data-label="delta"
            >D</button>
          </div>
        </template>
      );

      const rawMatches = findAll(".item");
      const hiddenMatches = findAll(".hidden");
      assert.true(
        hiddenMatches.length > 1,
        "the drift fixture measures several non-navigable matches"
      );
      assert.true(
        hiddenMatches.length < rawMatches.length,
        "the drift fixture also measures navigable matches around the hidden ones"
      );

      const apiItems = api.items();
      assert.true(
        apiItems.length > 0,
        "the drift fixture exposes a non-empty api item list"
      );
      apiItems.forEach((item, index) => {
        assert.strictEqual(
          api.indexOf(item),
          index,
          `indexOf preserves the api position of ${item.dataset.label} across hidden matches`
        );
        assert.true(
          api.focusElement(item),
          `focusElement accepts ${item.dataset.label} from the api item list`
        );
        assert.strictEqual(
          api.currentItem(),
          item,
          `focusElement lands on the exact ${item.dataset.label} element without DOM-query drift`
        );
        assert.strictEqual(
          api.indexOf(api.currentItem()),
          index,
          `the focused ${item.dataset.label} element maps back to its original api index`
        );
      });
    });

    // DECISION, not an invariant: this API exposes the cursor's legal landing places rather than
    // every raw selector match. The round-trip tests above remain the governing law if this
    // product choice is renegotiated.
    test("rovingApi: items exposes navigable matches only (decision)", async function (assert) {
      let api = null;
      const register = (value) => (api = value);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus itemSelector="[role=option]" onRegisterApi=register}}
          >
            <button class="item navigable" role="option">A</button>
            <button
              class="item"
              role="option"
              style="display: none;"
            >Hidden</button>
            <button class="item navigable" role="option">B</button>
            <button
              class="item"
              role="option"
              aria-disabled="true"
            >Disabled</button>
            <button class="item navigable" role="option">C</button>
          </div>
        </template>
      );

      const navigableMatches = findAll(".navigable");
      assert.deepEqual(
        api.items(),
        navigableMatches,
        "DECISION: items exposes exactly the measured navigable matches in DOM order"
      );
    });
  }
);
