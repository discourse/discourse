import { acceptance } from "helpers/qunit-helpers";

acceptance("CategoryChooser", {
  loggedIn: true,
  settings: {
    allow_uncategorized_topics: false
  }
});

QUnit.test("does not display uncategorized if not allowed", assert => {
  visit("/");
  click('#create-topic');

  expandSelectKit('.category-chooser');

  andThen(() => {
    assert.ok(selectKit('.category-chooser').rowByIndex(0).name() !== 'uncategorized');
  });
});

QUnit.test("prefill category when category_id is set", assert => {
  visit("/new-topic?category_id=1");

  andThen(() => {
    assert.equal(selectKit('.category-chooser').header.name(), 'bug');
  });
});
