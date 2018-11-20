import { acceptance } from "helpers/qunit-helpers";

acceptance("Group Card");

QUnit.test("group card", async assert => {
  await visit("/t/301/1");
  assert.ok(invisible("#group-card"), "user card is invisible by default");

  await click("a.mention-group:first");
  assert.ok(visible("#group-card"), "card should appear");
});
