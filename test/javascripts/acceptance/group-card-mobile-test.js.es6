import { acceptance } from "helpers/qunit-helpers";

acceptance("Group Card - Mobile", { mobileView: true });

QUnit.test("group card", assert => {
  visit("/t/301/1");

  assert.ok(invisible("#group-card"), "user card is invisible by default");
  click("a.mention-group:first");

  andThen(() => {
    assert.ok(visible(".group-details-container"), "group page show be shown");
  });
});
