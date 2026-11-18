import { getOwner } from "@ember/owner";
import { click, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { addGlobalNotice } from "discourse/components/global-notice";
import KeyValueStore from "discourse/lib/key-value-store";
import { disableClearA11yAnnouncementsInTests } from "discourse/services/a11y";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

const store = new KeyValueStore("discourse_");

acceptance("Global notice - logs notice", function (needs) {
  needs.user({ admin: true });
  needs.settings({ alert_admins_if_errors_per_hour: 100 });

  // Plugin notices are never cleared, so this one hides itself after the test.
  let errorNoticeVisible = false;

  needs.hooks.beforeEach(() => {
    disableClearA11yAnnouncementsInTests();
    store.setItem("logs-notice-text", "Errors are piling up");
  });

  needs.hooks.afterEach(() => {
    store.removeItem("logs-notice-text");
    errorNoticeVisible = false;
  });

  test("shows the stored notice until it is dismissed", async function (assert) {
    await visit("/");

    assert
      .dom(".alert-logs-notice .text")
      .hasText("Errors are piling up", "shows the notice after a reload");

    await click(".alert-logs-notice .close");

    assert.dom(".alert-logs-notice").doesNotExist("hides the dismissed notice");
  });

  test("announces a notice politely, and its close button has a name", async function (assert) {
    await visit("/");

    assert
      .dom("#a11y-announcements-polite")
      .hasText("Errors are piling up", "the notice is announced");
    assert
      .dom(".alert-logs-notice")
      .doesNotHaveAttribute("role", "the notice is not a second live region");
    assert.dom(".alert-logs-notice .close").hasAria("label", "Close");
    assert
      .dom(".alert-logs-notice .close")
      .hasAttribute(
        "aria-describedby",
        "global-notice-text-alert-logs-notice",
        "the close button points at the message it closes"
      );
  });

  test("announces a notice that appears while the page is open", async function (assert) {
    await visit("/");

    getOwner(this).lookup("service:site").set("isReadOnly", true);
    await settled();

    assert
      .dom("#a11y-announcements-polite")
      .hasText(i18n("read_only_mode.enabled"), "the new notice is announced");
  });

  test("announces an error notice assertively", async function (assert) {
    errorNoticeVisible = true;
    addGlobalNotice("Something failed", "test-error-notice", {
      level: "error",
      visibility: () => errorNoticeVisible,
    });

    await visit("/");

    assert
      .dom("#a11y-announcements-assertive")
      .hasText("Something failed", "the error is announced assertively");
    assert
      .dom(".alert.test-error-notice")
      .doesNotHaveAttribute("role", "the notice is not a second live region");
  });
});
