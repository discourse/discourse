import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import UserAction from "discourse/models/user-action";

module("Unit | Model | user-action", function (hooks) {
  setupTest(hooks);

  test("collapsing likes", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const actions = UserAction.collapseStream([
      store.createRecord("user-action", {
        action_type: UserAction.TYPES.likes_given,
        topic_id: 1,
        user_id: 1,
        post_number: 1,
      }),
      store.createRecord("user-action", {
        action_type: UserAction.TYPES.edits,
        topic_id: 2,
        user_id: 1,
        post_number: 1,
      }),
      store.createRecord("user-action", {
        action_type: UserAction.TYPES.likes_given,
        topic_id: 1,
        user_id: 2,
        post_number: 1,
      }),
    ]);

    assert.strictEqual(actions.length, 2);
    assert.strictEqual(actions[0].children.length, 1);
    assert.strictEqual(actions[0].children[0].items.length, 2);
  });
});
