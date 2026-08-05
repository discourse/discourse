import { tracked } from "@glimmer/tracking";
import {
  click,
  fillIn,
  find,
  findAll,
  render,
  settled,
  triggerEvent,
  triggerKeyEvent,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/lib/virtualizer";
import DSelect from "discourse/ui-kit/select/d-select";

// A tracked `@items` holder, so a test can shrink a windowed list at runtime and prove the
// render survives a window whose published virtual items briefly outrun the new item array.
class ItemsHolder {
  @tracked items;

  constructor(items) {
    this.items = items;
  }
}

const CLIENT_ITEMS = Array.from({ length: 4 }, (_, index) => ({
  id: index + 1,
  name: `Item ${index + 1}`,
}));
// A client list large enough that its tail sits off the bounded viewport's mounted window, so
// the last option is unmounted and only a logical jump (End) reaches it. The whole list is
// navigable — the engine renders a client source in full and DVirtualList windows the DOM.
const LOADED_ITEMS = Array.from({ length: 40 }, (_, index) => ({
  id: index,
  name: `Item ${index}`,
}));
const LAST_INDEX = LOADED_ITEMS.length - 1;
const LAST_OPTION_SELECTOR = `[role="option"][data-index="${LAST_INDEX}"]`;
const LISTBOX_SELECTOR = ".d-virtual-list > ul[role='listbox']";
const OPTION_SELECTOR = `${LISTBOX_SELECTOR} > [role='option']`;

async function openSelect() {
  await click("[role='combobox']");
}

module(
  "Integration | ui-kit | select | DSelect virtual list",
  function (hooks) {
    setupRenderingTest(hooks);

    test("the listbox is the inner container of a virtual-list viewport", async function (assert) {
      await render(<template><DSelect @items={{CLIENT_ITEMS}} /></template>);
      await openSelect();

      assert
        .dom(".d-virtual-list")
        .exists("the menu has a virtual-list scroll viewport");
      assert
        .dom(LISTBOX_SELECTOR)
        .exists("the semantic listbox is inside the virtual-list viewport");
      assert
        .dom(OPTION_SELECTOR)
        .exists(
          { count: CLIENT_ITEMS.length },
          "every client item is a direct child option of the inner listbox"
        );
      assert.strictEqual(
        find("ul[role='listbox']").parentElement,
        find(".d-virtual-list"),
        "the bare listbox is not mounted outside the virtual-list viewport"
      );
    });

    test("listbox attributes are forwarded to the inner container", async function (assert) {
      await render(
        <template>
          <DSelect @items={{CLIENT_ITEMS}} @multiple={{true}} />
        </template>
      );
      await openSelect();
      const controls = find("[role='combobox']").getAttribute("aria-controls");

      assert
        .dom(LISTBOX_SELECTOR)
        .hasAttribute("id", controls, "the input controls the inner listbox")
        .hasAttribute(
          "aria-multiselectable",
          "true",
          "multiple-selection semantics reach the inner listbox"
        )
        .hasClass(
          "d-combobox__listbox",
          "the consumer class reaches the inner listbox"
        );
    });

    test("options retain engine-computed set metadata", async function (assert) {
      await render(<template><DSelect @items={{CLIENT_ITEMS}} /></template>);
      await openSelect();

      const options = findAll("ul[role='listbox'] > [role='option']");
      assert.strictEqual(
        options.length,
        CLIENT_ITEMS.length,
        "the fully-mounted list contains every option"
      );
      options.forEach((option, index) => {
        assert
          .dom(option)
          .hasAttribute(
            "aria-posinset",
            String(index + 1),
            "the engine supplies the option's absolute position"
          )
          .hasAttribute(
            "aria-setsize",
            String(CLIENT_ITEMS.length),
            "the engine supplies the client source's true size"
          );
      });
    });

    test("the virtual list has no reveal sentinel", async function (assert) {
      const observerStub = sinon.stub(window, "IntersectionObserver").value(
        class {
          observe() {}
          disconnect() {}
        }
      );

      try {
        const items = Array.from({ length: 51 }, (_, index) => ({
          id: index + 1,
          name: `Item ${index + 1}`,
        }));
        await render(<template><DSelect @items={{items}} /></template>);
        await openSelect();

        assert
          .dom(".d-combobox__sentinel")
          .doesNotExist("the list has no reveal-sentinel row");
        assert
          .dom(".load-more-sentinel")
          .doesNotExist("server reveal is not driven by DLoadMore");
      } finally {
        observerStub.restore();
      }
    });

    test("roving highlight remains wired to options in the inner listbox", async function (assert) {
      await render(<template><DSelect @items={{CLIENT_ITEMS}} /></template>);
      await openSelect();

      assert
        .dom(`${OPTION_SELECTOR}:first-child`)
        .hasClass("--active", "opening highlights the first inner-list option");

      await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");

      assert
        .dom(`${OPTION_SELECTOR}:nth-child(2)`)
        .hasClass("--active", "ArrowDown advances the inner-list highlight");
    });

    test("a pending server reveal appends presentational frontier skeletons", async function (assert) {
      let engine;
      let releaseReveal;
      let revealRequested = false;
      const firstPage = CLIENT_ITEMS.map((item, index) => ({
        ...item,
        ...(index === 0 ? { onSelect: (value) => (engine = value) } : {}),
      }));
      const revealPromise = new Promise((resolve) => (releaseReveal = resolve));
      const load = (_filter, { offset = 0 }) => {
        if (offset === 0) {
          return { items: firstPage, total: 8 };
        }

        revealRequested = true;
        return revealPromise;
      };

      await render(
        <template><DSelect @load={{load}} @debounce={{false}} /></template>
      );
      await openSelect();
      await click(findAll("ul[role='listbox'] > [role='option']")[0]);

      try {
        engine.revealMore();
        await waitUntil(() => revealRequested);
        await waitUntil(() => find(".d-combobox__skeleton"));

        const skeletons = findAll(
          "ul[role='listbox'] > [role='presentation'].d-combobox__skeleton"
        );
        const options = findAll("ul[role='listbox'] > [role='option']");
        assert.true(skeletons.length > 0, "the pending page has frontier rows");
        assert.strictEqual(
          options.at(-1).nextElementSibling,
          skeletons[0],
          "the skeleton frontier starts immediately after the loaded options"
        );
        skeletons.forEach((skeleton) => {
          assert
            .dom(skeleton)
            .doesNotHaveAttribute(
              "aria-posinset",
              "a placeholder has no position in the option set"
            );
        });
        assert
          .dom(
            `${LISTBOX_SELECTOR} > [role='presentation'].d-combobox__skeleton`
          )
          .exists(
            "the skeleton frontier belongs to the virtual list's inner ul"
          );
      } finally {
        releaseReveal({
          items: Array.from({ length: 4 }, (_, index) => ({
            id: index + 5,
            name: `Item ${index + 5}`,
          })),
          total: 8,
        });
        await settled();
      }
    });

    test("a resolved client source has no frontier skeletons", async function (assert) {
      await render(<template><DSelect @items={{CLIENT_ITEMS}} /></template>);
      await openSelect();

      assert
        .dom("ul[role='listbox'] > .d-combobox__skeleton")
        .doesNotExist("a synchronous client list has no placeholder rows");
    });
  }
);

// Oracle for U-D change B1: DSelect committed-window keyboard reconcile under real
// windowing. A `static` DSelect (a select-only combobox: the non-editable trigger
// controls the listbox, so Home/End/Page navigate options) over 500 items in a bounded
// viewport mounts only a slice. A logical jump (End → the last option) must scroll the
// target in, then land the cursor on it AFTER the new window commits — with
// `aria-activedescendant` referencing a mounted option at every step, and the pinned
// active row kept mounted so DOM order stays monotonic.
module("Integration | ui-kit | select | DSelect logical nav", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    enableVirtualization();
  });

  hooks.afterEach(function () {
    disableVirtualization();
  });

  test("End lands the cursor on the last logical option after scrolling it into the window", async function (assert) {
    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 200px;
            overflow-y: auto;
          }
        </style>
        <DSelect @items={{LOADED_ITEMS}} @variant="static" />
      </template>
    );
    await openSelect();

    assert.true(
      findAll(OPTION_SELECTOR).length < LOADED_ITEMS.length,
      "the bounded viewport mounts only a window of the loaded options"
    );
    assert
      .dom(LAST_OPTION_SELECTOR)
      .doesNotExist("the last logical option is not mounted before the jump");

    await triggerKeyEvent("[role='combobox']", "keydown", "End");

    assert
      .dom(LAST_OPTION_SELECTOR)
      .exists("End scrolls the last logical option into the mounted window");
    const last = find(LAST_OPTION_SELECTOR);
    assert
      .dom(last)
      .hasClass(
        "--active",
        "the last logical option becomes the active highlight"
      );
    assert
      .dom("[role='combobox']")
      .hasAttribute(
        "aria-activedescendant",
        last.id,
        "the controller points aria-activedescendant at the last logical option"
      );
  });

  test("aria-activedescendant never dangles across an End/Home/PageDown/PageUp sequence", async function (assert) {
    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 200px;
            overflow-y: auto;
          }
        </style>
        <DSelect @items={{LOADED_ITEMS}} @variant="static" />
      </template>
    );
    await openSelect();

    const controller = find("[role='combobox']");
    for (const key of ["End", "Home", "PageDown", "PageUp"]) {
      await triggerKeyEvent(controller, "keydown", key);

      const id = controller.getAttribute("aria-activedescendant");
      assert.true(
        Boolean(id),
        `${key}: the controller has an active descendant`
      );
      const active = id ? document.getElementById(id) : null;
      assert.true(
        Boolean(active),
        `${key}: aria-activedescendant resolves to a mounted element (never dangles)`
      );
      assert.strictEqual(
        active?.getAttribute("role"),
        "option",
        `${key}: the active descendant is a listbox option`
      );
      assert
        .dom(active)
        .hasClass(
          "--active",
          `${key}: the active descendant carries the highlight`
        );
    }
  });

  test("shrinking a windowed list to fewer options renders without a stale-window crash", async function (assert) {
    const holder = new ItemsHolder(
      Array.from({ length: 300 }, (_, index) => ({
        id: index,
        name: `Item ${index}`,
      }))
    );

    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 150px;
            overflow-y: auto;
          }
        </style>
        <DSelect @items={{holder.items}} @variant="static" />
      </template>
    );
    await openSelect();
    assert.true(
      findAll(OPTION_SELECTOR).length < 300,
      "the large list opens windowed"
    );

    // Collapse the backing list far below the mounted window: the virtualizer's last
    // published window still references the old indices until it re-flushes, so the row
    // block must tolerate an item that is momentarily absent instead of throwing.
    holder.items = [
      { id: 0, name: "Item 0" },
      { id: 1, name: "Item 1" },
    ];
    await settled();

    assert
      .dom(OPTION_SELECTOR)
      .exists(
        { count: 2 },
        "the shrunken list renders its options without crashing the app"
      );
  });

  test("the pinned active row stays mounted and DOM order stays monotonic after scrolling away", async function (assert) {
    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 200px;
            overflow-y: auto;
          }
        </style>
        <DSelect @items={{LOADED_ITEMS}} @variant="static" />
      </template>
    );
    await openSelect();

    // Jump to the end (active + pinned at the last index), then scroll the viewport back
    // to the top: the window shows the first rows while the pinned active row stays mounted.
    await triggerKeyEvent("[role='combobox']", "keydown", "End");

    const viewport = find(".d-virtual-list");
    viewport.scrollTop = 0;
    await triggerEvent(viewport, "scroll");

    const indices = findAll(OPTION_SELECTOR).map((el) =>
      Number(el.dataset.index)
    );
    assert.true(
      indices.includes(LAST_INDEX),
      "the pinned active row (the last index) stays mounted after scrolling to the top"
    );
    for (let i = 1; i < indices.length; i++) {
      assert.true(
        indices[i] > indices[i - 1],
        `mounted options stay in ascending DOM order (${indices[i - 1]} < ${indices[i]}), pin included`
      );
    }
  });

  test("a new query scrolls the windowed list back to the top", async function (assert) {
    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 200px;
            overflow-y: auto;
          }
        </style>
        <DSelect @items={{LOADED_ITEMS}} />
      </template>
    );
    await openSelect();

    const viewport = find(".d-virtual-list");
    viewport.scrollTop = viewport.scrollHeight;
    await triggerEvent(viewport, "scroll");
    assert.true(
      viewport.scrollTop > 0,
      "the window is scrolled away from the top"
    );

    // A new query must return the windowed list to the top so results read from the first
    // row, not from wherever the previous scroll left the window.
    await fillIn("[role='combobox']", "Item 1");

    assert.strictEqual(
      find(".d-virtual-list").scrollTop,
      0,
      "the new query reset the windowed scroll to the top"
    );
  });
});

const GROUP_HEADER_SELECTOR = `${LISTBOX_SELECTOR} > .d-combobox__group-header`;
const GROUPED_ITEMS = [
  { id: 1, name: "Carrot", group: "Vegetables" },
  { id: 2, name: "Apple", group: "Fruits" },
  { id: 3, name: "Pea", group: "Vegetables" },
  { id: 4, name: "Pear", group: "Fruits" },
];

module("Integration | ui-kit | select | DSelect grouping", function (hooks) {
  setupRenderingTest(hooks);

  // Header behavior is opt-in: `groupBy` alone renders unlabeled splitters.
  const identityLabel = (key) => key;

  hooks.beforeEach(function () {
    enableVirtualization();
  });

  hooks.afterEach(function () {
    disableVirtualization();
  });

  test("groupBy renders a presentational header before each group, outside the option set", async function (assert) {
    await render(
      <template>
        <DSelect
          @items={{GROUPED_ITEMS}}
          @groupBy="group"
          @groupLabel={{identityLabel}}
        />
      </template>
    );
    await openSelect();

    assert
      .dom(GROUP_HEADER_SELECTOR)
      .exists({ count: 2 }, "a header is injected before each non-empty group");
    findAll(GROUP_HEADER_SELECTOR).forEach((header) =>
      assert
        .dom(header)
        .hasAttribute(
          "role",
          "presentation",
          "a header is presentational, never an option"
        )
    );
    assert
      .dom(OPTION_SELECTOR)
      .exists(
        { count: GROUPED_ITEMS.length },
        "headers are not part of the option set"
      );
    assert.deepEqual(
      findAll(GROUP_HEADER_SELECTOR).map((header) => header.textContent.trim()),
      ["Vegetables", "Fruits"],
      "headers read the group keys in first-appearance order"
    );
  });

  test("options carry contiguous logical indices and absolute positions across headers", async function (assert) {
    await render(
      <template>
        <DSelect
          @items={{GROUPED_ITEMS}}
          @groupBy="group"
          @groupLabel={{identityLabel}}
        />
      </template>
    );
    await openSelect();

    const options = findAll(OPTION_SELECTOR);
    assert.deepEqual(
      options.map((option) => option.getAttribute("data-logical-index")),
      ["0", "1", "2", "3"],
      "logical indices are contiguous over options, skipping headers"
    );
    assert.deepEqual(
      options.map((option) => option.getAttribute("aria-posinset")),
      ["1", "2", "3", "4"],
      "aria-posinset numbers options only"
    );
    options.forEach((option) =>
      assert
        .dom(option)
        .hasAttribute(
          "aria-setsize",
          "4",
          "aria-setsize is the option count, not the row count"
        )
    );
    findAll(GROUP_HEADER_SELECTOR).forEach((header) =>
      assert
        .dom(header)
        .doesNotHaveAttribute(
          "aria-posinset",
          "a header has no position in the option set"
        )
    );
  });

  test("keyboard navigation steps through options and never lands on a header", async function (assert) {
    await render(
      <template>
        <DSelect
          @items={{GROUPED_ITEMS}}
          @groupBy="group"
          @groupLabel={{identityLabel}}
        />
      </template>
    );
    await openSelect();

    const controller = find("[role='combobox']");
    const activeText = () => {
      const id = controller.getAttribute("aria-activedescendant");
      const active = id ? document.getElementById(id) : null;
      assert.strictEqual(
        active?.getAttribute("role"),
        "option",
        "the active descendant is always an option, never a header"
      );
      return active?.textContent.trim();
    };

    // Opening seeds the cursor on the first option, so the walk starts from the row after it
    // rather than spending a press on the one the list already points at.
    const visited = [activeText()];
    for (let i = 1; i < GROUPED_ITEMS.length; i++) {
      await triggerKeyEvent(controller, "keydown", "ArrowDown");
      visited.push(activeText());
    }

    assert.deepEqual(
      visited,
      ["Carrot", "Pea", "Apple", "Pear"],
      "ArrowDown walks the grouped option order, skipping the headers between groups"
    );
  });

  // The scroll element is measured synchronously when the engine mounts, at which point the
  // menu has not been positioned and so has no height — the first window computes empty. Every
  // later measurement arrives through a ResizeObserver, on the browser's own schedule, which
  // nothing awaits: under load the delivery lands after a test has already read the listbox,
  // which is how these grouping tests fail on CI while passing on an idle machine.
  //
  // Neutralising the observer pins the contract that removes the race rather than reproducing
  // it: the first window must not depend on a resize delivery at all, because whatever changes
  // the menu's size re-measures the list directly.
  test("the first window does not depend on a resize delivery", async function (assert) {
    const observerStub = sinon.stub(window, "ResizeObserver").value(
      class {
        observe() {}
        unobserve() {}
        disconnect() {}
      }
    );

    try {
      await render(
        <template>
          <DSelect
            @items={{GROUPED_ITEMS}}
            @groupBy="group"
            @groupLabel={{identityLabel}}
          />
        </template>
      );
      await openSelect();

      assert
        .dom(OPTION_SELECTOR)
        .exists(
          { count: GROUPED_ITEMS.length },
          "the window is mounted by the time the open has settled"
        );
    } finally {
      observerStub.restore();
    }
  });

  test("each option names its own group via aria-describedby on its header's label span", async function (assert) {
    await render(
      <template>
        <DSelect
          @items={{GROUPED_ITEMS}}
          @groupBy="group"
          @groupLabel={{identityLabel}}
        />
      </template>
    );
    await openSelect();

    assert
      .dom(".d-combobox__group-labels")
      .doesNotExist("no separate label store renders");

    // Grouped order is [Vegetables] Carrot, Pea, [Fruits] Apple, Pear.
    const expectedGroup = ["Vegetables", "Vegetables", "Fruits", "Fruits"];
    findAll(OPTION_SELECTOR).forEach((option, index) => {
      const headerId = option.getAttribute("aria-describedby");
      assert.notStrictEqual(
        headerId,
        null,
        "the option references a group label"
      );
      const label = headerId ? document.getElementById(headerId) : null;
      assert.true(
        !!label?.closest(".d-combobox__group-header"),
        "the description lives on the group's own header row"
      );
      assert.true(
        !!label?.closest("[role='listbox']"),
        "the description node is inside the listbox"
      );
      assert.strictEqual(
        label?.textContent.trim(),
        expectedGroup[index],
        "the referenced label is the option's own group, so a screen reader names the group"
      );
    });
  });

  test("the header label span owns the group id", async function (assert) {
    await render(
      <template>
        <DSelect
          @items={{GROUPED_ITEMS}}
          @groupBy="group"
          @groupLabel={{identityLabel}}
        />
      </template>
    );
    await openSelect();

    assert
      .dom(".d-combobox__group-labels")
      .doesNotExist("no separate label store renders");
    assert.deepEqual(
      findAll(`${GROUP_HEADER_SELECTOR} [id]`).map((label) =>
        label.textContent.trim()
      ),
      ["Vegetables", "Fruits"],
      "each header carries one id-bearing label, in group order"
    );
    findAll(OPTION_SELECTOR).forEach((option) => {
      const headerId = option.getAttribute("aria-describedby");
      assert.strictEqual(
        document.querySelectorAll(`[id="${CSS.escape(headerId)}"]`).length,
        1,
        "the group id has a single owner, so the reference is unambiguous"
      );
    });
  });

  test("a pinned header keeps descriptions resolvable after its group scrolls past the window", async function (assert) {
    const items = Array.from({ length: 60 }, (_, index) => ({
      id: index,
      name: `Item ${index}`,
      group: index < 30 ? "First" : "Second",
    }));

    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 200px;
            overflow-y: auto;
          }
        </style>
        <DSelect
          @items={{items}}
          @groupBy="group"
          @groupLabel={{identityLabel}}
          @variant="static"
        />
      </template>
    );
    await openSelect();
    await triggerKeyEvent("[role='combobox']", "keydown", "End");

    // The window sits deep inside the second group, far past its header row —
    // only the pin keeps that header mounted. The first group has no mounted
    // options, so its header is correctly unmounted: description DOM stays
    // bounded by the window instead of scaling with the group count.
    const headers = findAll(GROUP_HEADER_SELECTOR);
    assert.strictEqual(
      headers.length,
      1,
      "only the group with mounted options keeps its header mounted"
    );
    assert
      .dom(headers[0])
      .hasText("Second", "the pinned header is the window's group");
    findAll(OPTION_SELECTOR).forEach((option) => {
      const headerId = option.getAttribute("aria-describedby");
      const label = headerId ? document.getElementById(headerId) : null;
      assert.strictEqual(
        label?.textContent.trim(),
        "Second",
        "a mounted option's group description resolves through the pinned header"
      );
    });
  });

  test("a window straddling a group boundary mounts both groups' headers", async function (assert) {
    const items = Array.from({ length: 60 }, (_, index) => ({
      id: index,
      name: `Item ${index}`,
      group: index < 30 ? "First" : "Second",
    }));
    const heldId = 29;

    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 200px;
            overflow-y: auto;
          }
        </style>
        <DSelect
          @items={{items}}
          @value={{heldId}}
          @groupBy="group"
          @groupLabel={{identityLabel}}
          @variant="static"
        />
      </template>
    );
    await openSelect();

    // The reveal centers the held last-of-First option, so the window covers the
    // boundary: First options via the pinned/revealed rows, Second options below.
    assert
      .dom(GROUP_HEADER_SELECTOR)
      .exists({ count: 2 }, "both groups touching the window keep a header");
    findAll(OPTION_SELECTOR).forEach((option) => {
      const expected =
        Number(option.dataset.logicalIndex) < 30 ? "First" : "Second";
      const headerId = option.getAttribute("aria-describedby");
      const label = headerId ? document.getElementById(headerId) : null;
      assert.strictEqual(
        label?.textContent.trim(),
        expected,
        "every mounted option resolves to its own group across the boundary"
      );
    });
  });

  test("a custom groupHeader block never leaks into option descriptions", async function (assert) {
    await render(
      <template>
        <DSelect
          @items={{GROUPED_ITEMS}}
          @groupBy="group"
          @groupLabel={{identityLabel}}
        >
          <:groupHeader as |item|>
            <strong class="fancy-header">▸ {{item.label}} ◂</strong>
          </:groupHeader>
        </DSelect>
      </template>
    );
    await openSelect();

    assert
      .dom(`${GROUP_HEADER_SELECTOR} .fancy-header`)
      .exists({ count: 2 }, "the custom block renders visibly in the header");
    findAll(OPTION_SELECTOR).forEach((option, index) => {
      const expected = index < 2 ? "Vegetables" : "Fruits";
      const headerId = option.getAttribute("aria-describedby");
      const label = headerId ? document.getElementById(headerId) : null;
      assert.true(
        !!label?.closest(".d-combobox__group-header"),
        "the id-bearing label stays inside the header row"
      );
      assert.true(
        label?.hasAttribute("hidden"),
        "the label span hides when the block supplies the visible header"
      );
      assert.strictEqual(
        label?.textContent.trim(),
        expected,
        "the description is the plain group label, never the block markup"
      );
    });
  });

  test("near-unique groups keep the mounted DOM bounded by the window", async function (assert) {
    const items = Array.from({ length: 120 }, (_, index) => ({
      id: index,
      name: `Item ${index}`,
      group: `Group ${index}`,
    }));

    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 200px;
            overflow-y: auto;
          }
        </style>
        <DSelect
          @items={{items}}
          @groupBy="group"
          @groupLabel={{identityLabel}}
          @variant="static"
        />
      </template>
    );
    await openSelect();

    assert
      .dom(".d-combobox__group-labels")
      .doesNotExist("no unwindowed label surface scales with the group count");
    // 120 labeled groups produce 240 rows; the mounted DOM must stay a window.
    assert.true(
      findAll(`${LISTBOX_SELECTOR} > li`).length < 60,
      `one row per group stays windowed (got ${
        findAll(`${LISTBOX_SELECTOR} > li`).length
      } of 240 rows)`
    );
  });

  test("groupBy without groupLabel renders splitters between groups", async function (assert) {
    await render(
      <template><DSelect @items={{GROUPED_ITEMS}} @groupBy="group" /></template>
    );
    await openSelect();

    assert
      .dom(`${LISTBOX_SELECTOR} > .d-combobox__divider`)
      .exists(
        { count: 1 },
        "two groups draw one splitter: boundaries only separate, never lead"
      );
    assert
      .dom(GROUP_HEADER_SELECTOR)
      .doesNotExist("no header rows render without labels");
    findAll(OPTION_SELECTOR).forEach((option) => {
      assert
        .dom(option)
        .doesNotHaveAttribute(
          "aria-describedby",
          "a splitter-bounded option carries no group description"
        );
    });
    assert.deepEqual(
      findAll(OPTION_SELECTOR).map((option) =>
        option.getAttribute("aria-posinset")
      ),
      ["1", "2", "3", "4"],
      "positions stay global and contiguous across splitters"
    );
  });

  test("a mixed groupLabel renders a header for the labeled group and a splitter for the rest", async function (assert) {
    const onlyVegetables = (key) => (key === "Vegetables" ? key : null);

    await render(
      <template>
        <DSelect
          @items={{GROUPED_ITEMS}}
          @groupBy="group"
          @groupLabel={{onlyVegetables}}
        />
      </template>
    );
    await openSelect();

    assert
      .dom(GROUP_HEADER_SELECTOR)
      .exists({ count: 1 }, "only the labeled group draws a header")
      .hasText("Vegetables");
    assert
      .dom(`${LISTBOX_SELECTOR} > .d-combobox__divider`)
      .exists({ count: 1 }, "the unlabeled boundary draws a splitter");
    const described = findAll(OPTION_SELECTOR).filter((option) =>
      option.hasAttribute("aria-describedby")
    );
    assert.deepEqual(
      described.map((option) => option.textContent.trim()),
      ["Carrot", "Pea"],
      "only the labeled group's options carry a group description"
    );
  });

  test("the create row carries no group description", async function (assert) {
    const createItem = (filter) => ({
      id: `new:${filter}`,
      name: `Create ${filter}`,
      __create: true,
    });

    await render(
      <template>
        <DSelect
          @items={{GROUPED_ITEMS}}
          @groupBy="group"
          @groupLabel={{identityLabel}}
          @allowCreate={{true}}
          @createItem={{createItem}}
        />
      </template>
    );
    await fillIn("[role='combobox']", "Pe");

    assert
      .dom("[role='option'].--create")
      .exists("the create row is offered for the unmatched query")
      .doesNotHaveAttribute(
        "aria-describedby",
        "the trailing create row is not announced as part of the last group"
      );
  });

  test("End lands the last logical option across interleaved headers after scrolling it in", async function (assert) {
    const items = Array.from({ length: 60 }, (_, index) => ({
      id: index,
      name: `Item ${index}`,
      group: index < 30 ? "First" : "Second",
    }));
    const lastLogicalSelector = `[role="option"][data-logical-index="${items.length - 1}"]`;

    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 200px;
            overflow-y: auto;
          }
        </style>
        <DSelect
          @items={{items}}
          @groupBy="group"
          @groupLabel={{identityLabel}}
          @variant="static"
        />
      </template>
    );
    await openSelect();

    assert.true(
      findAll(OPTION_SELECTOR).length < items.length,
      "the bounded viewport mounts only a window of the grouped options"
    );
    assert
      .dom(lastLogicalSelector)
      .doesNotExist("the last logical option is unmounted before the jump");

    await triggerKeyEvent("[role='combobox']", "keydown", "End");

    assert
      .dom(lastLogicalSelector)
      .exists(
        "End translates the logical target across the headers and scrolls the true last option in"
      );
    const last = find(lastLogicalSelector);
    assert
      .dom(last)
      .hasClass("--active", "the last logical option becomes the highlight");
    assert
      .dom("[role='combobox']")
      .hasAttribute(
        "aria-activedescendant",
        last.id,
        "the controller points aria-activedescendant at the last logical option"
      );
  });
});

// The roving seed only sees MOUNTED rows, and the reveal scroll that would mount an off-window
// selection is deferred a tick — so a selection past the window loses the seed to row zero, which
// then gets PINNED, keeping it mounted and surviving every later reconcile. The visible outcome
// is worse than a misplaced highlight: Enter activates the pinned row, silently replacing the
// held value with the first item.
module(
  "Integration | ui-kit | select | DSelect windowed selection seed",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      enableVirtualization();
    });

    hooks.afterEach(function () {
      disableVirtualization();
    });

    const HELD_INDEX = 30;

    test("opening with an off-window selection activates the selection, not row zero", async function (assert) {
      await render(
        <template>
          {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
          <style>
            .d-virtual-list {
              height: 200px;
              overflow-y: auto;
            }
          </style>
          <DSelect
            @items={{LOADED_ITEMS}}
            @value={{HELD_INDEX}}
            @variant="static"
          />
        </template>
      );
      await openSelect();

      const active = find(`${LISTBOX_SELECTOR} > [role='option'].--active`);
      assert.true(Boolean(active), "an option is active on open");
      assert.strictEqual(
        active?.dataset.index,
        String(HELD_INDEX),
        "the active row is the held selection, not the first mounted row"
      );
      assert
        .dom("[role='combobox']")
        .hasAttribute(
          "aria-activedescendant",
          active?.id,
          "the controller points at the selected row"
        );
      // The precondition for hearing "selected" on open: the row the cursor lands on has to
      // carry the state, not merely be the row that happens to be chosen. Assistive tech voices
      // state when the cursor arrives, so a seeded cursor on a row without it is silent.
      assert
        .dom(active)
        .hasAttribute(
          "aria-selected",
          "true",
          "the seeded row exposes its selected state for the cursor to voice"
        );

      await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");

      assert
        .dom(`${LISTBOX_SELECTOR} > [role='option'].--active`)
        .hasAttribute(
          "data-index",
          String(HELD_INDEX + 1),
          "ArrowDown continues from the selection, not from row one"
        );
    });
  }
);

// Opening a windowed list with nothing selected. A virtualizer mounts no rows until it has
// measured its viewport, which lands a tick after the listbox installs, and the open-time cursor
// seed reads mounted rows — so on a real windowed list it finds nothing to activate and the list
// opens with no cursor at all. The reader is told the list expanded but never which option it is
// on, and the first arrow press is spent landing on row one instead of moving off it. Every
// existing seed test passes because virtualization is disabled suite-wide, which mounts the whole
// list at install and hides the race.
module(
  "Integration | ui-kit | select | DSelect windowed open seed",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      enableVirtualization();
    });

    hooks.afterEach(function () {
      disableVirtualization();
    });

    test("opening a windowed static list activates the first option", async function (assert) {
      await render(
        <template>
          {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
          <style>
            .d-virtual-list {
              height: 200px;
              overflow-y: auto;
            }
          </style>
          <DSelect @items={{LOADED_ITEMS}} @variant="static" />
        </template>
      );

      await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");

      assert.dom(LISTBOX_SELECTOR).exists("ArrowDown opens the list");
      // Without this the test says nothing: a viewport that mounted every row is the
      // non-windowed case the rest of the suite already covers.
      assert.true(
        findAll(OPTION_SELECTOR).length < LOADED_ITEMS.length,
        "the bounded viewport mounts only a window of the options"
      );

      const first = find(OPTION_SELECTOR);
      assert
        .dom(first)
        .hasClass("--active", "the first option carries the visual cursor");
      assert
        .dom("[role='combobox']")
        .hasAttribute(
          "aria-activedescendant",
          first.id,
          "the controller points at the first option on open"
        );

      // The symptom a reader actually reports. A seed that lands late still leaves the next
      // press re-landing on row one, so asserting only the state above would pass while the
      // list still costs two presses to reach its second option.
      await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");

      assert
        .dom(`${LISTBOX_SELECTOR} > [role='option'].--active`)
        .hasAttribute(
          "data-index",
          "1",
          "the next press moves to the second option rather than seeding row one"
        );
    });
  }
);
