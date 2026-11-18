import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { addGlobalNotice } from "discourse/components/global-notice";
import KeyValueStore from "discourse/lib/key-value-store";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

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

    await click(".alert-logs-notice .close");

    assert.dom(".alert-logs-notice").doesNotExist("hides the dismissed notice");
  });

  test("announces a notice as a status, and its close button has a name", async function (assert) {
    await visit("/");

    assert.dom(".alert-logs-notice").hasAttribute("role", "status");
    assert.dom(".alert-logs-notice .close").hasAria("label", "Close");
    assert
      .dom(".alert-logs-notice .close")
      .hasAttribute(
        "aria-describedby",
        "global-notice-text-alert-logs-notice",
        "the close button points at the message it closes"
      );
  });

  test("announces an error notice as an alert", async function (assert) {
    addGlobalNotice("Something failed", "test-error-notice", {
      level: "error",
    });

    await visit("/");

    assert.dom(".alert.test-error-notice").hasAttribute("role", "alert");
  });
});
