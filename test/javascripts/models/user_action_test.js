/*global module:true test:true ok:true visit:true expect:true exists:true count:true present:true equal:true */

module("Discourse.UserAction");

test("collapsing likes", function () {
  var actions = Discourse.UserAction.collapseStream([
    Discourse.UserAction.create({
      action_type: Discourse.UserAction.LIKE,
      topic_id: 1,
      user_id: 1,
      post_number: 1
    }), Discourse.UserAction.create({
      action_type: Discourse.UserAction.EDIT,
      topic_id: 2,
      user_id: 1,
      post_number: 1
    }), Discourse.UserAction.create({
      action_type: Discourse.UserAction.LIKE,
      topic_id: 1,
      user_id: 2,
      post_number: 1
    })
  ]);

  equal(actions.length, 2);

  equal(actions[0].get('children.length'), 1);
  equal(actions[0].get('children')[0].items.length, 2);
});
