module("Discourse.TopicTrackingState");

test("sync", function () {

  var state = Discourse.TopicTrackingState.create();
  // fake track it
  state.states["t111"] = {last_read_post_number: null};

  state.updateSeen(111, 7);
  var list = {topics: [{
    highest_post_number: null,
    id: 111,
    unread: 10,
    new_posts: 10
    }]};

  state.sync(list, "new");

  equal(list.topics.length, 0, "expect new topic to be removed as it was seen");

});
