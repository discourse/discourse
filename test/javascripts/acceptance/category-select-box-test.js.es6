import { acceptance } from "helpers/qunit-helpers";

acceptance("CategorySelectBox", {
  loggedIn: true,
  settings: {
    allow_uncategorized_topics: false
  }
});

QUnit.test("does not display uncategorized if not allowed", assert => {
  visit("/");
  click('#create-topic');

  click(".category-select-box .select-box-header");
  andThen(() => {
    assert.ok(!exists('.category-select-box .select-box-row[title="uncategorized"]'));
  });
});

QUnit.test("prefill category when category_id is set", assert => {
  visit("/new-topic?category_id=1");

  andThen(() => {
    assert.equal(find('.category-select-box .current-selection').html().trim(), "bug");
  });
});
