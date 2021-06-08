import {
  acceptance,
  count,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";

acceptance("Admin - Suspend User", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.put("/admin/users/:user_id/suspend", () =>
      helper.response(200, {
        suspension: {
          suspended_till: "2099-01-01T12:00:00.000Z",
        },
      })
    );

    server.put("/admin/users/:user_id/unsuspend", () =>
      helper.response(200, {
        suspension: {
          suspended_till: null,
        },
      })
    );
  });

  test("suspend a user - cancel", async function (assert) {
    await visit("/admin/users/1234/regular");
    await click(".suspend-user");

    assert.equal(count(".suspend-user-modal:visible"), 1);

    await click(".d-modal-cancel");

    assert.ok(!exists(".suspend-user-modal:visible"));
  });

  test("suspend a user - cancel with input", async function (assert) {
    await visit("/admin/users/1234/regular");
    await click(".suspend-user");

    assert.equal(count(".suspend-user-modal:visible"), 1);

    await fillIn("input.suspend-reason", "for breaking the rules");
    await fillIn(".suspend-message", "this is an email reason why");

    await click(".d-modal-cancel");

    assert.equal(count(".bootbox.modal:visible"), 1);

    await click(".modal-footer .btn-default");
    assert.equal(count(".suspend-user-modal:visible"), 1);
    assert.equal(
      query(".suspend-message").value,
      "this is an email reason why"
    );

    await click(".d-modal-cancel");
    assert.equal(count(".bootbox.modal:visible"), 1);
    assert.ok(!exists(".suspend-user-modal:visible"));

    await click(".modal-footer .btn-primary");
    assert.ok(!exists(".bootbox.modal:visible"));
  });

  test("suspend, then unsuspend a user", async function (assert) {
    const suspendUntilCombobox = selectKit(".suspend-until .combobox");

    await visit("/admin/flags/active");

    await visit("/admin/users/1234/regular");

    assert.ok(!exists(".suspension-info"));

    await click(".suspend-user");

    assert.equal(count(".perform-suspend[disabled]"), 1, "disabled by default");

    await suspendUntilCombobox.expand();
    await suspendUntilCombobox.selectRowByValue("tomorrow");

    await fillIn("input.suspend-reason", "for breaking the rules");
    await fillIn(".suspend-message", "this is an email reason why");

    assert.ok(!exists(".perform-suspend[disabled]"), "no longer disabled");

    await click(".perform-suspend");

    assert.ok(!exists(".suspend-user-modal:visible"));
    assert.ok(exists(".suspension-info"));

    await click(".unsuspend-user");

    assert.ok(!exists(".suspension-info"));
  });
});
