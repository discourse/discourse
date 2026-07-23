import {
  click,
  find,
  findAll,
  render,
  settled,
  triggerKeyEvent,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DSelect from "discourse/ui-kit/select/d-select";

const CLIENT_ITEMS = Array.from({ length: 4 }, (_, index) => ({
  id: index + 1,
  name: `Item ${index + 1}`,
}));
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
