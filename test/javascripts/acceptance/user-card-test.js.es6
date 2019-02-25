import { acceptance } from "helpers/qunit-helpers";
import DiscourseURL from "discourse/lib/url";

acceptance("User Card");

QUnit.test("user card", async assert => {
  await visit("/");
  assert.ok(invisible("#user-card"), "user card is invisible by default");

  await click("a[data-user-card=eviltrout]:first");
  assert.ok(visible("#user-card"), "card should appear");

  sandbox.stub(DiscourseURL, "routeTo");
  await click(".card-content a.mention");
  assert.ok(DiscourseURL.routeTo.calledWith("/u/eviltrout"));
});
