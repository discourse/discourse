import { acceptance } from "helpers/qunit-helpers";

acceptance("Shared Drafts", { loggedIn: true });

QUnit.test("Viewing", assert => {
  visit("/t/some-topic/9");
  andThen(() => {
    assert.ok(find(".shared-draft-controls").length === 1);
    let categoryChooser = selectKit(".shared-draft-controls .category-chooser");
    assert.equal(categoryChooser.header().value(), "3");
  });

  click(".publish-shared-draft");
  click(".bootbox .btn-primary");

  andThen(() => {
    assert.ok(find(".shared-draft-controls").length === 0);
  });
});
