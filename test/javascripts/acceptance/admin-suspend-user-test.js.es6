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

QUnit.test("suspend a user - cancel", assert => {
  visit("/admin/users/1234/regular");
  click(".suspend-user");

  andThen(() => {
    assert.equal(find(".suspend-user-modal:visible").length, 1);
  });

  click(".d-modal-cancel");
  andThen(() => {
    assert.equal(find(".suspend-user-modal:visible").length, 0);
  });
});

QUnit.test("suspend, then unsuspend a user", assert => {
  const suspendUntilCombobox = selectKit(".suspend-until .combobox");

  visit("/admin/flags/active");

  visit("/admin/users/1234/regular");

  andThen(() => {
    assert.ok(!exists(".suspension-info"));
  });

  click(".suspend-user");

  andThen(() => {
    assert.equal(
      find(".perform-suspend[disabled]").length,
      1,
      "disabled by default"
    );
  });

  suspendUntilCombobox.expand().selectRowByValue("tomorrow");

  fillIn(".suspend-reason", "for breaking the rules");
  fillIn(".suspend-message", "this is an email reason why");
  andThen(() => {
    assert.equal(
      find(".perform-suspend[disabled]").length,
      0,
      "no longer disabled"
    );
  });
  click(".perform-suspend");
  andThen(() => {
    assert.equal(find(".suspend-user-modal:visible").length, 0);
    assert.ok(exists(".suspension-info"));
  });

  click(".unsuspend-user");
  andThen(() => {
    assert.ok(!exists(".suspension-info"));
  });
});
