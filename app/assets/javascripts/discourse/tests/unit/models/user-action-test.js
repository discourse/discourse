import { module, test } from "qunit";
import UserAction from "discourse/models/user-action";

module("Unit | Model | user-action", function () {
  test("collapsing likes", function (assert) {
    let actions = UserAction.collapseStream([
      UserAction.create({
        action_type: UserAction.TYPES.likes_given,
        topic_id: 1,
        user_id: 1,
        post_number: 1,
      }),
      UserAction.create({
        action_type: UserAction.TYPES.edits,
        topic_id: 2,
        user_id: 1,
        post_number: 1,
      }),
      UserAction.create({
        action_type: UserAction.TYPES.likes_given,
        topic_id: 1,
        user_id: 2,
        post_number: 1,
      }),
    ]);

    assert.strictEqual(actions.length, 2);
    assert.strictEqual(actions[0].get("children.length"), 1);
    assert.strictEqual(actions[0].get("children")[0].items.length, 2);
  });
});
