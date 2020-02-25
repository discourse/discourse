import TopicTrackingState from "discourse/models/topic-tracking-state";
import createStore from "helpers/create-store";
import Category from "discourse/models/category";
import { NotificationLevels } from "discourse/lib/notification-levels";

QUnit.module("model:topic-tracking-state");

QUnit.test("sync", function(assert) {
  const state = TopicTrackingState.create();
  state.states["t111"] = { last_read_post_number: null };

  state.updateSeen(111, 7);
  const list = {
    topics: [
      {
        highest_post_number: null,
        id: 111,
        unread: 10,
        new_posts: 10
      }
    ]
  };

  state.sync(list, "new");
  assert.equal(
    list.topics.length,
    0,
    "expect new topic to be removed as it was seen"
  );
});

QUnit.test("subscribe to category", function(assert) {
  const store = createStore();
  const darth = store.createRecord("category", { id: 1, slug: "darth" }),
    luke = store.createRecord("category", {
      id: 2,
      slug: "luke",
      parentCategory: darth
    }),
    categoryList = [darth, luke];

  sandbox.stub(Category, "list").returns(categoryList);

  const state = TopicTrackingState.create();

  state.trackIncoming("c/darth/1/l/latest");

  state.notify({
    message_type: "new_topic",
    topic_id: 1,
    payload: { category_id: 2, topic_id: 1 }
  });
  state.notify({
    message_type: "new_topic",
    topic_id: 2,
    payload: { category_id: 3, topic_id: 2 }
  });
  state.notify({
    message_type: "new_topic",
    topic_id: 3,
    payload: { category_id: 1, topic_id: 3 }
  });

  assert.equal(
    state.get("incomingCount"),
    2,
    "expect to properly track incoming for category"
  );

  state.resetTracking();
  state.trackIncoming("c/darth/luke/2/l/latest");

  state.notify({
    message_type: "new_topic",
    topic_id: 1,
    payload: { category_id: 2, topic_id: 1 }
  });
  state.notify({
    message_type: "new_topic",
    topic_id: 2,
    payload: { category_id: 3, topic_id: 2 }
  });
  state.notify({
    message_type: "new_topic",
    topic_id: 3,
    payload: { category_id: 1, topic_id: 3 }
  });

  assert.equal(
    state.get("incomingCount"),
    1,
    "expect to properly track incoming for subcategory"
  );
});

QUnit.test("getSubCategoryIds", assert => {
  const store = createStore();
  const foo = store.createRecord("category", { id: 1, slug: "foo" });
  const bar = store.createRecord("category", {
    id: 2,
    slug: "bar",
    parent_category_id: foo.id
  });
  const baz = store.createRecord("category", {
    id: 3,
    slug: "baz",
    parent_category_id: bar.id
  });
  sandbox.stub(Category, "list").returns([foo, bar, baz]);

  const state = TopicTrackingState.create();
  assert.deepEqual(Array.from(state.getSubCategoryIds(1)), [1, 2, 3]);
  assert.deepEqual(Array.from(state.getSubCategoryIds(2)), [2, 3]);
  assert.deepEqual(Array.from(state.getSubCategoryIds(3)), [3]);
});

QUnit.test("countNew", assert => {
  const store = createStore();
  const foo = store.createRecord("category", { id: 1, slug: "foo" });
  const bar = store.createRecord("category", {
    id: 2,
    slug: "bar",
    parent_category_id: foo.id
  });
  const baz = store.createRecord("category", {
    id: 3,
    slug: "baz",
    parent_category_id: bar.id
  });
  sandbox.stub(Category, "list").returns([foo, bar, baz]);

  const state = TopicTrackingState.create();

  assert.equal(state.countNew(1), 0);
  assert.equal(state.countNew(2), 0);
  assert.equal(state.countNew(3), 0);

  state.states["t112"] = {
    last_read_post_number: null,
    id: 112,
    notification_level: NotificationLevels.TRACKING,
    category_id: 2
  };

  assert.equal(state.countNew(1), 1);
  assert.equal(state.countNew(2), 1);
  assert.equal(state.countNew(3), 0);

  state.states["t113"] = {
    last_read_post_number: null,
    id: 113,
    notification_level: NotificationLevels.TRACKING,
    category_id: 3
  };

  assert.equal(state.countNew(1), 2);
  assert.equal(state.countNew(2), 2);
  assert.equal(state.countNew(3), 1);

  state.states["t111"] = {
    last_read_post_number: null,
    id: 111,
    notification_level: NotificationLevels.TRACKING,
    category_id: 1
  };

  assert.equal(state.countNew(1), 3);
  assert.equal(state.countNew(2), 2);
  assert.equal(state.countNew(3), 1);
});
