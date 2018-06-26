import { acceptance } from "helpers/qunit-helpers";

acceptance("CategoryChooser", {
  loggedIn: true,
  settings: {
    allow_uncategorized_topics: false
  }
});

QUnit.test("does not display uncategorized if not allowed", assert => {
  const categoryChooser = selectKit(".category-chooser");

  visit("/");
  click("#create-topic");

  categoryChooser.expand();

  andThen(() => {
    assert.ok(categoryChooser.rowByIndex(0).name() !== "uncategorized");
  });
});

QUnit.test("prefill category when category_id is set", assert => {
  visit("/new-topic?category_id=1");

  andThen(() => {
    assert.equal(
      selectKit(".category-chooser")
        .header()
        .value(),
      1
    );
  });
});
