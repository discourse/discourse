import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import topicFixtures from "discourse/tests/fixtures/topic";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { cloneJSON } from "discourse-common/lib/object";
import I18n from "discourse-i18n";

acceptance("Topic - Slow Mode - enabled", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/t/1.json", () => {
      const json = cloneJSON(topicFixtures["/t/130.json"]);
      json.slow_mode_seconds = 600;
      json.slow_mode_enabled_until = "2040-01-01T04:00:00.000Z";

      return helper.response(json);
    });
    server.get("/t/2.json", () => {
      const json = cloneJSON(topicFixtures["/t/130.json"]);
      json.slow_mode_seconds = 0;
      json.slow_mode_enabled_until = null;

      return helper.response(json);
    });
  });

  needs.hooks.beforeEach(() => {
    updateCurrentUser({ moderator: true });
  });

  test("the slow mode dialog loads settings of currently enabled slow mode ", async function (assert) {
    await visit("/t/a-topic-with-enabled-slow-mode/1");
    await click(".toggle-admin-menu");
    await click(".topic-admin-slow-mode button");

    const slowModeType = selectKit(".slow-mode-type");
    assert.strictEqual(
      slowModeType.header().name(),
      I18n.t("topic.slow_mode_update.durations.10_minutes"),
      "slow mode interval is rendered"
    );

    // unfortunately we can't check exact date and time
    // but at least we can make sure that components for choosing date and time are rendered
    // (in case of inactive slow mode it would be only a combo box with text "Select a timeframe",
    // and date picker and time picker wouldn't be rendered)
    assert
      .dom("div.enabled-until span.name")
      .hasText(
        I18n.t("time_shortcut.custom"),
        "enabled until combobox is switched to the option Pick Date and Time"
      );

    assert.dom("input.date-picker").exists("date picker is rendered");
    assert.dom("input.time-input").exists("time picker is rendered");
  });

  test("'Enable' button changes to 'Update' button when slow mode is enabled", async function (assert) {
    await visit("/t/a-topic-with-disabled-slow-mode/2");
    await click(".toggle-admin-menu");
    await click(".topic-admin-slow-mode button");
    await click(".future-date-input-selector-header");

    assert
      .dom("div.d-modal__footer button.btn-primary span")
      .hasText(
        I18n.t("topic.slow_mode_update.enable"),
        "shows 'Enable' button when slow mode is disabled"
      );

    await visit("/t/a-topic-with-enabled-slow-mode/1");
    await click(".toggle-admin-menu");
    await click(".topic-admin-slow-mode button");
    await click(".future-date-input-selector-header");

    assert
      .dom("div.d-modal__footer button.btn-primary span")
      .hasText(
        I18n.t("topic.slow_mode_update.update"),
        "shows 'Update' button when slow mode is enabled"
      );
  });
});
