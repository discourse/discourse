import selectKit from "helpers/select-kit-helper";
import { acceptance } from "helpers/qunit-helpers";

acceptance("Review", {
  loggedIn: true
});

const user = ".reviewable-item[data-reviewable-id=1234]";

QUnit.test("It returns a list of reviewable items", async assert => {
  await visit("/review");

  assert.ok(find(".reviewable-item").length, "has a list of items");
  assert.ok(find(user).length);
  assert.ok(
    find(`${user}.reviewable-user`).length,
    "applies a class for the type"
  );
  assert.ok(
    find(`${user} .reviewable-action.approve`).length,
    "creates a button for approve"
  );
  assert.ok(
    find(`${user} .reviewable-action.reject`).length,
    "creates a button for reject"
  );
});

QUnit.test("Grouped by topic", async assert => {
  await visit("/review/topics");
  assert.ok(
    find(".reviewable-topic").length,
    "it has a list of reviewable topics"
  );
});

QUnit.test("Settings", async assert => {
  await visit("/review/settings");

  assert.ok(find(".reviewable-score-type").length, "has a list of bonuses");

  const field = selectKit(".reviewable-score-type:eq(0) .field .combo-box");
  await field.expand();
  await field.selectRowByValue("5");
  await click(".save-settings");

  assert.ok(find(".reviewable-settings .saved").length, "it saved");
});

QUnit.test("Flag related", async assert => {
  await visit("/review");

  assert.ok(
    find(".reviewable-flagged-post .post-contents .username a[href]").length,
    "it has a link to the user"
  );

  assert.equal(
    find(".reviewable-flagged-post .post-body")
      .html()
      .trim(),
    "<b>cooked content</b>"
  );

  assert.equal(find(".reviewable-flagged-post .reviewable-score").length, 2);
});

QUnit.test("Flag related", async assert => {
  await visit("/review/1");

  assert.ok(
    find(".reviewable-flagged-post").length,
    "it shows the flagged post"
  );
});

QUnit.test("Clicking the buttons triggers actions", async assert => {
  await visit("/review");
  await click(`${user} .reviewable-action.approve`);
  assert.equal(find(user).length, 0, "it removes the reviewable on success");
});

QUnit.test("Editing a reviewable", async assert => {
  const topic = ".reviewable-item[data-reviewable-id=4321]";
  await visit("/review");
  assert.ok(find(`${topic} .reviewable-action.approve`).length);
  assert.ok(!find(`${topic} .category-name`).length);
  assert.equal(find(`${topic} .discourse-tag:eq(0)`).text(), "hello");
  assert.equal(find(`${topic} .discourse-tag:eq(1)`).text(), "world");

  assert.equal(
    find(`${topic} .post-body`)
      .text()
      .trim(),
    "existing body"
  );

  await click(`${topic} .reviewable-action.edit`);
  await click(`${topic} .reviewable-action.save-edit`);
  assert.ok(
    find(`${topic} .reviewable-action.approve`).length,
    "saving without changes is a cancel"
  );
  await click(`${topic} .reviewable-action.edit`);

  assert.equal(
    find(`${topic} .reviewable-action.approve`).length,
    0,
    "when editing actions are disabled"
  );

  await fillIn(".editable-field.payload-raw textarea", "new raw contents");
  await click(`${topic} .reviewable-action.cancel-edit`);
  assert.equal(
    find(`${topic} .post-body`)
      .text()
      .trim(),
    "existing body",
    "cancelling does not update the value"
  );

  await click(`${topic} .reviewable-action.edit`);
  let category = selectKit(`${topic} .category-id .select-kit`);
  await category.expand();
  await category.selectRowByValue("6");

  let tags = selectKit(`${topic} .payload-tags .mini-tag-chooser`);
  await tags.expand();
  await tags.fillInFilter("monkey");
  await tags.selectRowByValue("monkey");

  await fillIn(".editable-field.payload-raw textarea", "new raw contents");
  await click(`${topic} .reviewable-action.save-edit`);

  assert.equal(find(`${topic} .discourse-tag:eq(0)`).text(), "hello");
  assert.equal(find(`${topic} .discourse-tag:eq(1)`).text(), "world");
  assert.equal(find(`${topic} .discourse-tag:eq(2)`).text(), "monkey");

  assert.equal(
    find(`${topic} .post-body`)
      .text()
      .trim(),
    "new raw contents"
  );
  assert.equal(
    find(`${topic} .category-name`)
      .text()
      .trim(),
    "support"
  );
});
