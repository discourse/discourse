import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";
import sinon from "sinon";

acceptance("User Preferences - Account", function (needs) {
  needs.user({
    username: "charlie",
  });

  needs.pretender((server, helper) => {
    server.delete("/u/charlie.json", () => helper.response({ success: true }));

    server.post("/u/eviltrout/preferences/revoke-account", () => {
      return helper.response({
        success: true,
      });
    });
  });

  test("Delete dialog", async function (assert) {
    sinon.stub(DiscourseURL, "redirectAbsolute");

    await visit("/u/charlie/preferences/account");
    await click(".delete-account .btn-danger");

    await click(".dialog-footer .btn-danger");

    assert.strictEqual(
      query(".dialog-body").textContent.trim(),
      I18n.t("user.deleted_yourself"),
      "confirmation dialog is shown"
    );

    await click(".dialog-footer .btn-primary");

    assert.ok(
      DiscourseURL.redirectAbsolute.calledWith("/"),
      "redirects to home after deleting"
    );
  });

  test("connected accounts", async function (assert) {
    await visit("/u/eviltrout/preferences/account");

    assert.ok(
      exists(".pref-associated-accounts"),
      "it has the connected accounts section"
    );

    assert.ok(
      query(
        ".pref-associated-accounts table tr:nth-of-type(1) td:nth-of-type(1)"
      ).innerHTML.includes("Facebook"),
      "it lists facebook"
    );

    await click(
      ".pref-associated-accounts table tr:nth-of-type(1) td:last-child button"
    );

    assert.ok(
      query(
        ".pref-associated-accounts table tr:nth-of-type(1) td:last-of-type"
      ).innerHTML.includes("Connect")
    );
  });
});
