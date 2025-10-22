import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Model | bookmark", function (hooks) {
  setupTest(hooks);

  test("topicForList - Topic bookmarkable", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const bookmark = store.createRecord("bookmark", {
      id: 1,
      bookmarkable_type: "Topic",
      bookmarkable_id: 999,
      linked_post_number: null,
      topic_id: 999,
      fancy_title: "Some test topic",
      last_read_post_number: 23,
      highest_post_number: 30,
    });

    assert.strictEqual(
      bookmark.topicForList.linked_post_number,
      null,
      "linked_post_number is null"
    );
  });

  test("topicForList - Post bookmarkable", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const bookmark = store.createRecord("bookmark", {
      id: 1,
      bookmarkable_type: "Post",
      bookmarkable_id: 999,
      linked_post_number: 787,
      topic_id: 999,
      fancy_title: "Some test topic",
      last_read_post_number: 23,
      highest_post_number: 30,
    });

    assert.strictEqual(
      bookmark.topicForList.linked_post_number,
      787,
      "linked_post_number is correct"
    );
  });
});
