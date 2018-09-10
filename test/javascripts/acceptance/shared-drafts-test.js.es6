import { acceptance } from "helpers/qunit-helpers";

acceptance("Shared Drafts", { loggedIn: true });

QUnit.test("Viewing", async assert => {
  await visit("/t/some-topic/9");
  assert.ok(find(".shared-draft-controls").length === 1);
  let categoryChooser = selectKit(".shared-draft-controls .category-chooser");
  assert.equal(categoryChooser.header().value(), "3");

  await click(".publish-shared-draft");
  await click(".bootbox .btn-primary");

  assert.ok(find(".shared-draft-controls").length === 0);
});
