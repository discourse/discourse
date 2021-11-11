import { module, test } from "qunit";
import I18n from "I18n";
import { NEW_TOPIC_KEY } from "discourse/models/composer";
import User from "discourse/models/user";
import UserDraft from "discourse/models/user-draft";

module("Unit | Model | user-draft", function () {
  test("stream", function (assert) {
    const user = User.create({ id: 1, username: "eviltrout" });
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
    const drafts = [
      UserDraft.create({
        draft_key: "topic_1",
        post_number: "10",
      }),
      UserDraft.create({
        draft_key: NEW_TOPIC_KEY,
      }),
    ];

    assert.strictEqual(drafts.length, 2, "drafts count is right");
    assert.strictEqual(
      drafts[1].draftType,
      I18n.t("drafts.new_topic"),
      "loads correct draftType label"
    );
  });
});
