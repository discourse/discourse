import {
  acceptance
}
from "helpers/qunit-helpers";

acceptance("Dashboard Next", {
  loggedIn: true
});

QUnit.test("Visit dashboard next page", assert => {
  visit("/admin");

  andThen(() => {
    assert.ok($('.dashboard-next').length, "has dashboard-next class");
  });
});
