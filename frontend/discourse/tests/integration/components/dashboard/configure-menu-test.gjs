import { click, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import ConfigureMenu from "discourse/admin/components/dashboard/configure-menu";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const FOUR_SECTIONS = [
  { id: "highlights", visible: true },
  { id: "reports", visible: true },
  { id: "traffic", visible: false },
  { id: "engagement", visible: true },
];

function dataTransferStub() {
  return { effectAllowed: null, setData() {}, getData: () => "" };
}

module("Integration | Component | Dashboard | ConfigureMenu", function (hooks) {
  setupRenderingTest(hooks);

  test("renders one row per section", async function (assert) {
    const sections = FOUR_SECTIONS;
    const noop = () => {};

    await render(
      <template>
        <ConfigureMenu
          @sections={{sections}}
          @onReorder={{noop}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    assert.dom(".db-configure__row").exists({ count: 4 });
    assert.dom('[data-section-id="highlights"]').exists();
    assert.dom('[data-section-id="reports"]').exists();
    assert.dom('[data-section-id="traffic"]').exists();
    assert.dom('[data-section-id="engagement"]').exists();
  });

  test("toggle click fires @onToggleVisibility with the section id", async function (assert) {
    const sections = FOUR_SECTIONS;
    const calls = [];
    const onToggle = (id) => calls.push(id);
    const noop = () => {};

    await render(
      <template>
        <ConfigureMenu
          @sections={{sections}}
          @onReorder={{noop}}
          @onToggleVisibility={{onToggle}}
        />
      </template>
    );

    await click('[data-section-id="highlights"] .d-toggle-switch__checkbox');
    assert.deepEqual(calls, ["highlights"]);
  });

  test("drag-and-drop fires @onReorder with computed indices", async function (assert) {
    const sections = FOUR_SECTIONS;
    const calls = [];
    const onReorder = (from, to) => calls.push([from, to]);
    const noop = () => {};

    await render(
      <template>
        <ConfigureMenu
          @sections={{sections}}
          @onReorder={{onReorder}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    const source = '[data-section-id="reports"]';
    const target = '[data-section-id="highlights"]';
    const dataTransfer = dataTransferStub();

    await triggerEvent(source, "dragstart", { dataTransfer });
    await triggerEvent(target, "dragover", { dataTransfer, offsetY: 1 });
    await triggerEvent(target, "drop", { dataTransfer, offsetY: 1 });

    assert.deepEqual(
      calls.at(-1),
      [1, 0],
      "drop above index 0 moves source from 1 to 0"
    );
  });

  test("desktop renders the drag handle and not the arrows", async function (assert) {
    const sections = FOUR_SECTIONS;
    const noop = () => {};

    await render(
      <template>
        <ConfigureMenu
          @sections={{sections}}
          @onReorder={{noop}}
          @onToggleVisibility={{noop}}
        />
      </template>
    );

    assert.dom(".db-configure__drag-handle").exists({ count: 4 });
    assert.dom(".db-configure__arrow").doesNotExist();
  });
});

module(
  "Integration | Component | Dashboard | ConfigureMenu | Mobile",
  function (hooks) {
    hooks.beforeEach(function () {
      forceMobile();
    });

    setupRenderingTest(hooks);

    test("hides the drag handle and renders arrow buttons", async function (assert) {
      const sections = FOUR_SECTIONS;
      const noop = () => {};

      await render(
        <template>
          <ConfigureMenu
            @sections={{sections}}
            @onReorder={{noop}}
            @onToggleVisibility={{noop}}
          />
        </template>
      );

      assert.dom(".db-configure__drag-handle").doesNotExist();
      assert.dom(".db-configure__arrow").exists({ count: 8 });
    });

    test("arrow buttons fire @onReorder", async function (assert) {
      const sections = FOUR_SECTIONS;
      const calls = [];
      const onReorder = (from, to) => calls.push([from, to]);
      const noop = () => {};

      await render(
        <template>
          <ConfigureMenu
            @sections={{sections}}
            @onReorder={{onReorder}}
            @onToggleVisibility={{noop}}
          />
        </template>
      );

      await click(
        '[data-section-id="reports"] .db-configure__arrow:first-child'
      );
      assert.deepEqual(calls.at(-1), [1, 0]);

      await click(
        '[data-section-id="highlights"] .db-configure__arrow:last-child'
      );
      assert.deepEqual(calls.at(-1), [0, 1]);
    });

    test("first row's up button and last row's down button are disabled", async function (assert) {
      const sections = FOUR_SECTIONS;
      const noop = () => {};

      await render(
        <template>
          <ConfigureMenu
            @sections={{sections}}
            @onReorder={{noop}}
            @onToggleVisibility={{noop}}
          />
        </template>
      );

      assert
        .dom('[data-section-id="highlights"] .db-configure__arrow:first-child')
        .isDisabled("first row's up arrow is disabled");
      assert
        .dom('[data-section-id="engagement"] .db-configure__arrow:last-child')
        .isDisabled("last row's down arrow is disabled");
      assert
        .dom('[data-section-id="reports"] .db-configure__arrow:first-child')
        .isNotDisabled("middle row's up arrow is enabled");
    });
  }
);
