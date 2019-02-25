import { acceptance, replaceCurrentUser } from "helpers/qunit-helpers";

acceptance("Composer and uncategorized is not allowed", {
  loggedIn: true,
  pretend(server, helper) {
    server.get("/draft.json", () => {
      return helper.response({
        draft: null,
        draft_sequence: 42
      });
    });
  },
  settings: {
    enable_whispers: true,
    allow_uncategorized_topics: false
  }
});

QUnit.test("Disable body until category is selected", async assert => {
  replaceCurrentUser({ admin: false, staff: false, trust_level: 1 });

  await visit("/");
  await click("#create-topic");
  assert.ok(exists(".d-editor-input"), "the composer input is visible");
  assert.ok(
    exists(".title-input .popup-tip.bad.hide"),
    "title errors are hidden by default"
  );
  assert.ok(
    exists(".d-editor-textarea-wrapper .popup-tip.bad.hide"),
    "body errors are hidden by default"
  );
  assert.ok(
    exists(".d-editor-textarea-wrapper.disabled"),
    "textarea is disabled"
  );

  const categoryChooser = selectKit(".category-chooser");

  await categoryChooser.expand();
  await categoryChooser.selectRowByValue(2);

  assert.ok(
    find(".d-editor-textarea-wrapper.disabled").length === 0,
    "textarea is enabled"
  );

  await fillIn(".d-editor-input", "Now I can type stuff");
  await categoryChooser.expand();
  await categoryChooser.selectRowByValue("__none__");

  assert.ok(
    find(".d-editor-textarea-wrapper.disabled").length === 0,
    "textarea is still enabled"
  );
});
