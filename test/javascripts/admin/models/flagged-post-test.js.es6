import FlaggedPost from 'admin/models/flagged-post';

module("Discourse.FlaggedPost");

test('delete first post', function() {
  sandbox.stub(Discourse, 'ajax');

  FlaggedPost.create({ id: 1, topic_id: 2, post_number: 1 })
           .deletePost();

  ok(Discourse.ajax.calledWith("/t/2", { type: 'DELETE', cache: false }), "it deleted the topic");
});

test('delete second post', function() {
  sandbox.stub(Discourse, 'ajax');

  FlaggedPost.create({ id: 1, topic_id: 2, post_number: 2 })
           .deletePost();

  ok(Discourse.ajax.calledWith("/posts/1", { type: 'DELETE', cache: false }), "it deleted the post");
});
