import TopicTrackingState from 'discourse/models/topic-tracking-state';

module("model:topic-tracking-state");

test("sync", function (assert) {
  const state = TopicTrackingState.create();
  state.states["t111"] = {last_read_post_number: null};

  state.updateSeen(111, 7);
  const list = {topics: [{
    highest_post_number: null,
    id: 111,
    unread: 10,
    new_posts: 10
  }]};

  state.sync(list, "new");
  assert.equal(list.topics.length, 0, "expect new topic to be removed as it was seen");
});
