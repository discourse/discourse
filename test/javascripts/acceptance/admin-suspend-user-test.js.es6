import { acceptance } from "helpers/qunit-helpers";

acceptance("Admin - Suspend User", { loggedIn: true });

QUnit.test("suspend a user - cancel", assert => {
  visit("/admin/users/1234/regular");
  click(".suspend-user");

  andThen(() => {
    assert.equal(find('.suspend-user-modal:visible').length, 1);
  });

  click('.cancel-suspend');
  andThen(() => {
    assert.equal(find('.suspend-user-modal:visible').length, 0);
  });
});

QUnit.test("suspend a user", assert => {
  visit("/admin/users/1234/regular");
  click(".suspend-user");

  andThen(() => {
    assert.equal(find('.perform-suspend[disabled]').length, 1, 'disabled by default');
  });
  fillIn('.suspend-duration', 12);
  fillIn('.suspend-reason', "for breaking the rules");
  fillIn('.suspend-message', "this is an email reason why");
  andThen(() => {
    assert.equal(find('.perform-suspend[disabled]').length, 0);
  });
  click('.perform-suspend');
  andThen(() => {
    assert.equal(find('.suspend-user-modal:visible').length, 0);
  });
});
