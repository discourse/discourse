import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import KeyValueStore from "discourse/lib/key-value-store";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

const store = new KeyValueStore("discourse_");

acceptance("Global notice - logs notice", function (needs) {
  needs.user({ admin: true });
  needs.settings({ alert_admins_if_errors_per_hour: 100 });

  needs.hooks.beforeEach(() => {
    store.setItem("logs-notice-text", "Errors are piling up");
  });

  needs.hooks.afterEach(() => {
    store.removeItem("logs-notice-text");
  });

  test("shows the stored notice until it is dismissed", async function (assert) {
    await visit("/");

    assert
      .dom(".alert-logs-notice .text")
      .hasText("Errors are piling up", "shows the notice after a reload");
    assert
      .dom(".alert-logs-notice .close")
      .hasAria("label", i18n("close"), "names the close button");

    await click(".alert-logs-notice .close");

    assert.dom(".alert-logs-notice").doesNotExist("hides the dismissed notice");
  });
});
