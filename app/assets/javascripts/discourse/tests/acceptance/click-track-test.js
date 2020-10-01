import pretender from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Click Track", {});

QUnit.test("Do not track mentions", async (assert) => {
  pretender.post("/clicks/track", () => assert.ok(false));

  await visit("/t/internationalization-localization/280");
  assert.ok(find(".user-card.show").length === 0, "card should not appear");

  await click("article[data-post-id=3651] a.mention");
  assert.ok(find(".user-card.show").length === 1, "card appear");
  assert.equal(currentURL(), "/t/internationalization-localization/280");
});
