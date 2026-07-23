import { tracked } from "@glimmer/tracking";
import {
  click,
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
// A client list SMALLER than the engine's client chunk (CLIENT_CHUNK=50) so every option is
// loaded and navigable — U-D lands before U-C, so the engine still caps the client render
// window and a larger list would never make its tail navigable. Still far larger than the
// bounded viewport's mounted window, so the last option is off-window and only a logical jump
// (End) reaches it.
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
});
