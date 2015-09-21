import TopicTrackingState from 'discourse/models/topic-tracking-state';
import createStore from 'helpers/create-store';

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

test("subscribe to category", function(assert){

  const store = createStore();
  const darth = store.createRecord('category', {id: 1, slug: 'darth'}),
    luke = store.createRecord('category', {id: 2, slug: 'luke', parentCategory: darth}),
    categoryList = [darth, luke];

  sandbox.stub(Discourse.Category, 'list').returns(categoryList);


  const state = TopicTrackingState.create();

  state.trackIncoming('c/darth/l/latest');

  state.notify({message_type: 'new_topic', topic_id: 1, payload: {category_id: 2, topic_id: 1}});
  state.notify({message_type: 'new_topic', topic_id: 2, payload: {category_id: 3, topic_id: 2}});
  state.notify({message_type: 'new_topic', topic_id: 3, payload: {category_id: 1, topic_id: 3}});

  assert.equal(state.get("incomingCount"), 2, "expect to properly track incoming for category");

  state.resetTracking();
  state.trackIncoming('c/darth/luke/l/latest');

  state.notify({message_type: 'new_topic', topic_id: 1, payload: {category_id: 2, topic_id: 1}});
  state.notify({message_type: 'new_topic', topic_id: 2, payload: {category_id: 3, topic_id: 2}});
  state.notify({message_type: 'new_topic', topic_id: 3, payload: {category_id: 1, topic_id: 3}});

  assert.equal(state.get("incomingCount"), 1, "expect to properly track incoming for subcategory");
});
