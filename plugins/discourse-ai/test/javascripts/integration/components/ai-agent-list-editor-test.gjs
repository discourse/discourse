import { tracked } from "@glimmer/tracking";
import {
  find,
  findAll,
  focus,
  render,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { i18n } from "discourse-i18n";
import AiAgent from "discourse/plugins/discourse-ai/discourse/admin/models/ai-agent";
import AiAgentListEditor from "discourse/plugins/discourse-ai/discourse/components/ai-agent-list-editor";

const LAYOUT = ".ai-agent-list-editor__layout";
const LAYOUT_KEY = "ai-agent-list-layout";

function layoutName(layout) {
  return `${i18n("discourse_ai.layout.label")}, ${i18n(
    `discourse_ai.layout.${layout}`
  )}`;
}

module(
  "Integration | Component | AiAgentListEditor | layout",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.keyValueStore = this.owner.lookup("service:key-value-store");
      this.keyValueStore.remove(LAYOUT_KEY);
      this.wide = tracked(true);
      const wide = this.wide;
      // A medium screen is also a small one; without `sm` the site reports a mobile view.
      sinon.stub(this.owner.lookup("service:capabilities"), "viewport").value({
        sm: true,
        get md() {
          return wide.value;
        },
      });
      this.agents = {
        content: [
          AiAgent.create({
            id: 1,
            name: "Helper",
            description: "Answers questions",
            enabled: true,
            features: [],
          }),
        ],
      };
    });

    hooks.afterEach(function () {
      this.keyValueStore.remove(LAYOUT_KEY);
    });

    test("keeps today's menu without new select controls", async function (assert) {
      const agents = this.agents;
      await render(
        <template><AiAgentListEditor @agents={{agents}} /></template>
      );

      assert
        .dom(".fk-d-menu__trigger[data-identifier='agent-list-layout']")
        .exists();
      assert.dom(LAYOUT).doesNotExist();
    });

    module("with new select controls", function (flagHooks) {
      flagHooks.beforeEach(function () {
        this.siteSettings.enable_new_select_controls = true;
      });

      test("shows only the current layout's icon, and is named by the layout", async function (assert) {
        const agents = this.agents;
        await render(
          <template><AiAgentListEditor @agents={{agents}} /></template>
        );

        assert.dSelect(LAYOUT).hasValue("table");
        assert
          .dom(LAYOUT)
          .hasAttribute("role", "combobox")
          .hasAria("label", layoutName("table"));
        assert.dom(`${LAYOUT} .d-icon-discourse-table`).exists();
        assert.dom(`${LAYOUT} .d-select__value`).doesNotExist();
        assert.dom(`${LAYOUT} .d-select__caret`).doesNotExist();
      });

      test("lists both layouts with their icons and checks the current one", async function (assert) {
        const agents = this.agents;
        await render(
          <template><AiAgentListEditor @agents={{agents}} /></template>
        );
        await dSelect(LAYOUT).open();

        assert.dSelect(LAYOUT).hasOptions(["table", "card"]);
        assert.deepEqual(
          findAll("[role='option']").map((row) => row.dataset.name),
          [i18n("discourse_ai.layout.table"), i18n("discourse_ai.layout.card")]
        );
        assert
          .dom("[role='option'][data-value='table'] .d-icon-discourse-table")
          .exists();
        assert.dom("[role='option'][data-value='card'] .d-icon-table").exists();
        assert.dSelect(LAYOUT).hasSelectedOption("table");
        assert
          .dom(
            "[role='option'][data-value='table'] .d-select__option-selected-icon"
          )
          .exists();
      });

      test("stores the picked layout and lays the list out with it", async function (assert) {
        const agents = this.agents;
        await render(
          <template><AiAgentListEditor @agents={{agents}} /></template>
        );
        await dSelect(LAYOUT).select("card");

        assert.strictEqual(this.keyValueStore.get(LAYOUT_KEY), "card");
        assert.dom(".ai-agent-list-editor.--layout-card").exists();
        assert.dSelect(LAYOUT).hasValue("card");
        assert.dom(LAYOUT).hasAria("label", layoutName("card"));
        assert.dom(`${LAYOUT} .d-icon-table`).exists();
      });

      test("starts at the stored layout", async function (assert) {
        this.keyValueStore.set({ key: LAYOUT_KEY, value: "card" });
        const agents = this.agents;
        await render(
          <template><AiAgentListEditor @agents={{agents}} /></template>
        );

        assert.dSelect(LAYOUT).hasValue("card");
        assert.dom(".ai-agent-list-editor.--layout-card").exists();
      });

      test("opens under the trigger, lined up with its end", async function (assert) {
        const agents = this.agents;
        await render(
          <template><AiAgentListEditor @agents={{agents}} /></template>
        );
        await dSelect(LAYOUT).open();

        assert
          .dom(find("[role='listbox']").closest("[data-placement]"))
          .hasAttribute("data-placement", "bottom-end");
      });

      test("keeps the layout when Backspace is pressed on it, and doesn't say it was cleared", async function (assert) {
        const announce = sinon.spy(
          this.owner.lookup("service:a11y"),
          "announce"
        );
        const agents = this.agents;
        await render(
          <template><AiAgentListEditor @agents={{agents}} /></template>
        );
        await dSelect(LAYOUT).select("card");
        await focus(LAYOUT);
        await triggerKeyEvent(LAYOUT, "keydown", "Backspace");

        assert.dSelect(LAYOUT).hasValue("card");
        assert.false(
          announce.calledWith(i18n("d_select.selection_cleared")),
          "nothing was cleared"
        );
      });

      test("is only offered on a medium or wider screen", async function (assert) {
        this.wide.value = false;
        const agents = this.agents;
        await render(
          <template><AiAgentListEditor @agents={{agents}} /></template>
        );

        assert.dom(LAYOUT).doesNotExist();
      });
    });
  }
);
