import { acceptance } from "helpers/qunit-helpers";

acceptance("CategoryChooser - with tags", {
  loggedIn: true,
  site: { can_tag_topics: true },
  settings: {
    tagging_enabled: true,
    allow_uncategorized_topics: false
  }
});

QUnit.test("resets tags when changing category", async assert => {
  const categoryChooser = selectKit(".category-chooser");
  const miniTagChooser = selectKit(".mini-tag-chooser");
  const findSelected = () =>
    find(".mini-tag-chooser .mini-tag-chooser-header .selected-name").text();

  await visit("/");
  await click("#create-topic");
  await miniTagChooser.expand();
  await miniTagChooser.selectRowByValue("monkey");

  assert.equal(findSelected(), "monkey");

  await categoryChooser.expand();
  await categoryChooser.selectRowByValue(6);

  assert.equal(findSelected(), "optional tags");

  await miniTagChooser.expand();
  await miniTagChooser.selectRowByValue("monkey");

  assert.equal(findSelected(), "monkey");

  await categoryChooser.expand();
  await categoryChooser.selectNoneRow();

  assert.equal(findSelected(), "optional tags");
});
