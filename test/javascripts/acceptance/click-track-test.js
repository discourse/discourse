import pretender from "helpers/create-pretender";
import { acceptance } from "helpers/qunit-helpers";

acceptance("Click Track", {});

QUnit.skip("Do not track mentions", async assert => {
  pretender.post("/clicks/track", () => assert.ok(false));

  await visit("/t/internationalization-localization/280");
  assert.ok(invisible(".user-card"), "card should not appear");

  await click("article[data-post-id=3651] a.mention");
  assert.ok(visible(".user-card"), "card should appear");
  assert.equal(currentURL(), "/t/internationalization-localization/280");
});
