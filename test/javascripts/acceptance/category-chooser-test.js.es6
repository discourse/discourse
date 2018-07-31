import { acceptance } from "helpers/qunit-helpers";

acceptance("CategoryChooser", {
  loggedIn: true,
  settings: {
    allow_uncategorized_topics: false
  }
});

QUnit.test("does not display uncategorized if not allowed", async assert => {
  const categoryChooser = selectKit(".category-chooser");

  await visit("/");
  await click("#create-topic");

  await categoryChooser.expand();

  assert.ok(categoryChooser.rowByIndex(0).name() !== "uncategorized");
});

// TO-DO: fix the test to work with new code to land on category page
// (https://github.com/discourse/discourse/commit/7d9c97d66141d35d00258fe544211d9fd7f79a76)
// QUnit.test("prefill category when category_id is set", async assert => {
//   await visit("/new-topic?category_id=1");

//   assert.equal(
//     selectKit(".category-chooser")
//       .header()
//       .value(),
//     1
//   );
// });
