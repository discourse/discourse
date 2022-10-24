import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";
import sinon from "sinon";

acceptance("User Profile - Account - Self Delete", function (needs) {
  needs.user({
    username: "charlie",
  });

  needs.pretender((server, helper) => {
    server.delete("/u/charlie.json", () => helper.response({ success: true }));
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
});
