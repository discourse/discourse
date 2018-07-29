import { acceptance } from "helpers/qunit-helpers";

acceptance("Admin - Suspend User", {
  loggedIn: true,

  pretend(server, helper) {
    server.put("/admin/users/:user_id/suspend", () =>
      helper.response(200, {
        suspension: {
          suspended: true
        }
      })
    );

    server.put("/admin/users/:user_id/unsuspend", () =>
      helper.response(200, {
        suspension: {
          suspended: false
        }
      })
    );
  }
});

QUnit.test("suspend a user - cancel", async assert => {
  await visit("/admin/users/1234/regular");
  await click(".suspend-user");

  assert.equal(find(".suspend-user-modal:visible").length, 1);

  await click(".d-modal-cancel");

  assert.equal(find(".suspend-user-modal:visible").length, 0);
});

QUnit.test("suspend, then unsuspend a user", async assert => {
  const suspendUntilCombobox = selectKit(".suspend-until .combobox");

  await visit("/admin/flags/active");

  await visit("/admin/users/1234/regular");

  assert.ok(!exists(".suspension-info"));

  await click(".suspend-user");

  assert.equal(
    find(".perform-suspend[disabled]").length,
    1,
    "disabled by default"
  );

  await suspendUntilCombobox.expand();
  await suspendUntilCombobox.selectRowByValue("tomorrow");

  await fillIn(".suspend-reason", "for breaking the rules");
  await fillIn(".suspend-message", "this is an email reason why");

  assert.equal(
    find(".perform-suspend[disabled]").length,
    0,
    "no longer disabled"
  );

  await click(".perform-suspend");

  assert.equal(find(".suspend-user-modal:visible").length, 0);
  assert.ok(exists(".suspension-info"));

  await click(".unsuspend-user");

  assert.ok(!exists(".suspension-info"));
});
