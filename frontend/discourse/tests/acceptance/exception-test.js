import {
  resetOnerror,
  settled,
  setupOnerror,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Exception page", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/badges.json", () => helper.response(500, {}));
  });

  test("renders the error page when a route fails to load", async function (assert) {
    await visit("/");

    // the error intentionally bubbles after the exception page renders
    setupOnerror(() => {});

    try {
      await visit("/badges");
    } catch {}
    await settled();

    assert.dom(".error-page").exists();
    assert
      .dom(".error-page .reason")
      .hasText(i18n("errors.reasons.server"), "shows the server error reason");
    assert
      .dom(".error-page .buttons .btn-primary")
      .exists("offers recovery buttons");

    resetOnerror();
  });
});
