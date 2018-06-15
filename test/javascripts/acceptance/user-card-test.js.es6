import { acceptance } from "helpers/qunit-helpers";

acceptance("User Card");

QUnit.test("user card", assert => {
  visit("/");

  assert.ok(invisible("#user-card"), "user card is invisible by default");
  click("a[data-user-card=eviltrout]:first");

  andThen(() => {
    assert.ok(visible("#user-card"), "card should appear");
  });
});
