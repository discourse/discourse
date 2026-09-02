import { tracked } from "@glimmer/tracking";
import { click, render, settled, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import KeyValueStore from "discourse/lib/key-value-store";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DPanelDock from "discourse/ui-kit/panel-dock";
import { i18n } from "discourse-i18n";

const PanelA = <template>
  <div data-test-panel="a">Alpha</div>
</template>;
const PanelB = <template>
  <div data-test-panel="b">Beta</div>
</template>;
const PanelC = <template>
  <div data-test-panel="c">Gamma</div>
</template>;

function tabs() {
  return [
    { id: "alpha", label: "Alpha", component: PanelA },
    { id: "beta", label: "Beta", component: PanelB },
    { id: "gamma", label: "Gamma", component: PanelC },
  ];
}

module("Integration | Component | DPanelDock supplemental", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.tabs = tabs();
  });

  test("restores the legacy layout schema", async function (assert) {
    new KeyValueStore("d_panel_dock_").setObject({
      key: "legacy-tools",
      value: { side: "end", width: 410, height: 280 },
    });

    await render(
      <template>
        <DPanelDock
          @context="legacy-tools"
          @isOpen={{true}}
          @tabs={{this.tabs}}
        />
      </template>
    );

    assert
      .dom(".d-panel-dock")
      .hasClass("--dock-end", "the legacy side is restored");
    assert
      .dom(".d-panel-dock__resizer")
      .hasAttribute("aria-valuenow", "410", "the legacy width is restored");
  });

  test("forwards chassis defaults and stamps persisted layouts", async function (assert) {
    await render(
      <template>
        <DPanelDock
          @context="forwarded-tools"
          @isOpen={{true}}
          @tabs={{this.tabs}}
          @dockable={{true}}
          @defaultSide="end"
          @defaultWidth={{420}}
        />
      </template>
    );

    assert.dom(".d-panel-dock").hasClass("--dock-end");
    assert.dom(".d-panel-dock__resizer").hasAttribute("aria-valuenow", "420");

    await click(".d-panel-dock__dock-button.--bottom");

    assert.deepEqual(
      new KeyValueStore("d_panel_dock_").getObject("forwarded-tools"),
      {
        mode: "docked",
        side: "bottom",
        width: 420,
        height: 320,
      },
      "writes use the complete docked schema"
    );
  });

  test("arrow navigation wraps without activating", async function (assert) {
    await render(
      <template>
        <DPanelDock
          @context="wrapped-tools"
          @isOpen={{true}}
          @tabs={{this.tabs}}
        />
      </template>
    );

    const renderedTabs = document.querySelectorAll("[role='tab']");
    renderedTabs[0].focus();
    await triggerKeyEvent(renderedTabs[0], "keydown", "ArrowLeft");

    assert.strictEqual(
      document.activeElement,
      renderedTabs[2],
      "ArrowLeft wraps focus to the final tab"
    );
    assert
      .dom(renderedTabs[0])
      .hasAria("selected", "true", "focus movement does not activate");
  });

  test("keeps close last and gives it a translated accessible name", async function (assert) {
    const close = () => {};

    await render(
      <template>
        <DPanelDock
          @context="closable-tools"
          @isOpen={{true}}
          @tabs={{this.tabs}}
          @dockable={{true}}
          @onClose={{close}}
        />
      </template>
    );

    const actions = document.querySelector(".d-panel-dock__actions");
    const closeButton = actions.lastElementChild;

    assert.dom(closeButton).hasClass("d-panel-dock__close", "close is last");
    assert
      .dom(closeButton)
      .hasAttribute("aria-label", i18n("panel_dock.close"));
  });

  test("falls back to the first tab when the internal selection is removed", async function (assert) {
    const state = new (class {
      @tracked tabs = tabs();
    })();

    await render(
      <template>
        <DPanelDock
          @context="changing-tools"
          @isOpen={{true}}
          @tabs={{state.tabs}}
        />
      </template>
    );

    await click(document.querySelectorAll("[role='tab']")[1]);
    state.tabs = [state.tabs[0], state.tabs[2]];
    await settled();

    assert
      .dom("[data-test-panel='a']")
      .exists("the first remaining tab becomes active");
    assert.dom("[role='tab']").exists({ count: 2 });
  });
});
