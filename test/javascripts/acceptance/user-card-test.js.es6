import { acceptance } from "helpers/qunit-helpers";

acceptance("User Card");

QUnit.test("user card", async assert => {
  await visit("/");
  assert.ok(invisible("#user-card"), "user card is invisible by default");

  await click("a[data-user-card=eviltrout]:first");
  assert.ok(visible("#user-card"), "card should appear");
});
