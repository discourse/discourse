import UserAction from "discourse/models/user-action";

QUnit.module("model: user-action");

QUnit.test("collapsing likes", assert => {
  var actions = UserAction.collapseStream([
    UserAction.create({
      action_type: UserAction.TYPES.likes_given,
      topic_id: 1,
      user_id: 1,
      post_number: 1
    }),
    UserAction.create({
      action_type: UserAction.TYPES.edits,
      topic_id: 2,
      user_id: 1,
      post_number: 1
    }),
    UserAction.create({
      action_type: UserAction.TYPES.likes_given,
      topic_id: 1,
      user_id: 2,
      post_number: 1
    })
  ]);

  assert.equal(actions.length, 2);
  assert.equal(actions[0].get("children.length"), 1);
  assert.equal(actions[0].get("children")[0].items.length, 2);
});
