import { acceptance } from "helpers/qunit-helpers";
import DiscourseURL from "discourse/lib/url";

acceptance("Group Card - Mobile", { mobileView: true });

QUnit.skip("group card", async assert => {
  await visit("/t/-/301/1");
  assert.ok(
    invisible("#group-card"),
    "mobile group card is invisible by default"
  );

  await click("a.mention-group:first");
  assert.ok(visible("#group-card"), "mobile group card should appear");

  sandbox.stub(DiscourseURL, "routeTo");
  await click(".card-content a.group-page-link");
  assert.ok(
    DiscourseURL.routeTo.calledWith("/g/discourse"),
    "it should navigate to the group page"
  );
});
