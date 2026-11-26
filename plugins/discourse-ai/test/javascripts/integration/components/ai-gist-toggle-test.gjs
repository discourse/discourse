import { findAll, focus, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { i18n } from "discourse-i18n";
import AiGistToggle from "discourse/plugins/discourse-ai/discourse/components/ai-gist-toggle";

const TOGGLE = ".topic-list-layout-trigger";
const PREFERENCE_KEY = "topicListLayout";

function layoutName(layout) {
  return `${i18n("discourse_ai.layout.label")}, ${i18n(
    `discourse_ai.summarization.topic_list_layout.button.${layout}`
  )}`;
}

module("Integration | Component | AiGistToggle", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    localStorage.removeItem(PREFERENCE_KEY);
    this.gists = this.owner.lookup("service:gists");
    sinon.stub(this.gists, "showToggle").get(() => true);
  });

  hooks.afterEach(function () {
    localStorage.removeItem(PREFERENCE_KEY);
  });

  test("keeps today's menu without new select controls", async function (assert) {
    await render(<template><AiGistToggle /></template>);

    assert.dom(`.fk-d-menu__trigger${TOGGLE}`).exists();
    assert.dom(".d-select").doesNotExist();
  });

  module("with new select controls", function (flagHooks) {
    flagHooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
    });

    test("shows only the current layout's icon, and is named by the layout", async function (assert) {
      await render(<template><AiGistToggle /></template>);

      assert.dSelect(TOGGLE).hasValue("table");
      assert
        .dom(TOGGLE)
        .hasAttribute("role", "combobox")
        .hasAria("label", layoutName("compact"));
      assert.dom(`${TOGGLE} .d-icon-discourse-table`).exists();
      assert.dom(`${TOGGLE} .d-select__value`).doesNotExist();
      assert.dom(`${TOGGLE} .d-select__caret`).doesNotExist();
    });

    test("lists both layouts with their icons, describes the expanded one and checks the current one", async function (assert) {
      await render(<template><AiGistToggle /></template>);
      await dSelect(TOGGLE).open();

      assert.dSelect(TOGGLE).hasOptions(["table", "table-ai"]);
      assert.deepEqual(
        findAll("[role='option']").map((row) => row.dataset.name),
        [
          i18n("discourse_ai.summarization.topic_list_layout.button.compact"),
          i18n("discourse_ai.summarization.topic_list_layout.button.expanded"),
        ]
      );
      assert
        .dom("[role='option'][data-value='table'] .d-icon-discourse-table")
        .exists();
      assert
        .dom(
          "[role='option'][data-value='table-ai'] .d-icon-discourse-table-sparkles"
        )
        .exists();
      assert
        .dom(
          "[role='option'][data-value='table-ai'] .d-select__option-description"
        )
        .hasText(
          i18n(
            "discourse_ai.summarization.topic_list_layout.button.expanded_description"
          )
        );
      assert.dSelect(TOGGLE).hasSelectedOption("table");
      assert
        .dom(
          "[role='option'][data-value='table'] .d-select__option-selected-icon"
        )
        .exists();
    });

    test("stores the picked layout and shows its icon", async function (assert) {
      await render(<template><AiGistToggle /></template>);
      await dSelect(TOGGLE).select("table-ai");

      assert.strictEqual(this.gists.currentPreference, "table-ai");
      assert.strictEqual(localStorage.getItem(PREFERENCE_KEY), "table-ai");
      assert.dSelect(TOGGLE).hasValue("table-ai");
      assert.dom(TOGGLE).hasAria("label", layoutName("expanded"));
      assert.dom(`${TOGGLE} .d-icon-discourse-table-sparkles`).exists();
    });

    test("starts at the stored layout", async function (assert) {
      this.gists.setPreference("table-ai");
      await render(<template><AiGistToggle /></template>);

      assert.dSelect(TOGGLE).hasValue("table-ai");
      assert.dom(`${TOGGLE} .d-icon-discourse-table-sparkles`).exists();
    });

    test("keeps the layout when Backspace is pressed on it", async function (assert) {
      await render(<template><AiGistToggle /></template>);
      await dSelect(TOGGLE).select("table-ai");
      await focus(TOGGLE);
      await triggerKeyEvent(TOGGLE, "keydown", "Backspace");

      assert.dSelect(TOGGLE).hasValue("table-ai");
    });
  });
});
