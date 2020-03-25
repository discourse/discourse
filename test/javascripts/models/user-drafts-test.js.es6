import UserDraft from "discourse/models/user-draft";
import { NEW_TOPIC_KEY } from "discourse/models/composer";
import User from "discourse/models/user";

QUnit.module("model:user-drafts");

QUnit.test("stream", assert => {
  const user = User.create({ id: 1, username: "eviltrout" });
  const stream = user.get("userDraftsStream");
  assert.present(stream, "a user has a drafts stream by default");
  assert.equal(stream.get("itemsLoaded"), 0, "no items are loaded by default");
  assert.blank(stream.get("content"), "no content by default");
});

QUnit.test("draft", assert => {
  const drafts = [
    UserDraft.create({
      draft_key: "topic_1",
      post_number: "10"
    }),
    UserDraft.create({
      draft_key: NEW_TOPIC_KEY
    })
  ];

  assert.equal(drafts.length, 2, "drafts count is right");
  assert.equal(
    drafts[1].get("draftType"),
    I18n.t("drafts.new_topic"),
    "loads correct draftType label"
  );
});
