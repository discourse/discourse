import {
  acceptance
}
from "helpers/qunit-helpers";

acceptance("Dashboard Next", {
  loggedIn: true
});

QUnit.test("Vist dashboard next page", assert => {
  visit("/admin/dashboard-next");

  andThen(() => {
    assert.ok($('.dashboard-next').length, "has dashboard-next class");
  });
});
