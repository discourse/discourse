import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { NEW_TOPIC_KEY } from "discourse/models/composer";
import { i18n } from "discourse-i18n";

module("Unit | Model | user-draft", function (hooks) {
  setupTest(hooks);

  test("stream", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const user = store.createRecord("user", { id: 1, username: "eviltrout" });
    const stream = user.userDraftsStream;

    assert.present(stream, "a user has a drafts stream by default");
    assert.strictEqual(
      stream.content.length,
      0,
      "no items are loaded by default"
    );
    assert.blank(stream.content, "no content by default");
  });

  test("draft", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const drafts = [
      store.createRecord("user-draft", {
        draft_key: "topic_1",
        post_number: "10",
      }),
      store.createRecord("user-draft", {
        draft_key: NEW_TOPIC_KEY,
      }),
    ];

    assert.strictEqual(drafts.length, 2, "drafts count is right");
    assert.strictEqual(
      drafts[1].draftType,
      i18n("drafts.new_topic"),
      "loads correct draftType label"
    );
  });
});
