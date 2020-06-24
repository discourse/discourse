import TopicTrackingState from "discourse/models/topic-tracking-state";
import createStore from "helpers/create-store";
import Category from "discourse/models/category";
import { NotificationLevels } from "discourse/lib/notification-levels";
import User from "discourse/models/user";

QUnit.module("model:topic-tracking-state", {
  beforeEach() {
    this.clock = sinon.useFakeTimers(new Date(2012, 11, 31, 12, 0).getTime());
  },

  afterEach() {
    this.clock.restore();
  }
});

QUnit.test("tag counts", function(assert) {
  const state = TopicTrackingState.create();

  state.loadStates([
    {
      topic_id: 1,
      last_read_post_number: null,
      tags: ["foo", "new"]
    },
    {
      topic_id: 2,
      last_read_post_number: null,
      tags: ["new"]
    },
    {
      topic_id: 3,
      last_read_post_number: null,
      tags: ["random"]
    },
    {
      topic_id: 4,
      last_read_post_number: 1,
      highest_post_number: 7,
      tags: ["unread"],
      notification_level: NotificationLevels.TRACKING
    },
    {
      topic_id: 5,
      last_read_post_number: 1,
      highest_post_number: 7,
      tags: ["bar", "unread"],
      notification_level: NotificationLevels.TRACKING
    },
    {
      topic_id: 6,
      last_read_post_number: 1,
      highest_post_number: 7,
      tags: null,
      notification_level: NotificationLevels.TRACKING
    }
  ]);

  const states = state.countTags(["new", "unread"]);

  assert.equal(states["new"].newCount, 2, "new counts");
  assert.equal(states["new"].unreadCount, 0, "new counts");
  assert.equal(states["unread"].unreadCount, 2, "unread counts");
  assert.equal(states["unread"].newCount, 0, "unread counts");
});

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
  const foo = store.createRecord("category", {
    id: 1,
    slug: "foo"
  });
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
  assert.equal(state.countNew(1, "missing-tag"), 0);
  assert.equal(state.countNew(2), 1);
  assert.equal(state.countNew(3), 0);

  state.states["t113"] = {
    last_read_post_number: null,
    id: 113,
    notification_level: NotificationLevels.TRACKING,
    category_id: 3,
    tags: ["amazing"]
  };

  assert.equal(state.countNew(1), 2);
  assert.equal(state.countNew(2), 2);
  assert.equal(state.countNew(3), 1);
  assert.equal(state.countNew(3, "amazing"), 1);
  assert.equal(state.countNew(3, "missing"), 0);

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

QUnit.test("mute topic", function(assert) {
  let currentUser = User.create({
    username: "chuck",
    muted_category_ids: []
  });

  const state = TopicTrackingState.create({ currentUser });

  state.trackMutedTopic(1);
  assert.equal(currentUser.muted_topics[0].topicId, 1);

  state.pruneOldMutedTopics();
  assert.equal(state.isMutedTopic(1), true);

  this.clock.tick(60000);
  state.pruneOldMutedTopics();
  assert.equal(state.isMutedTopic(1), false);
});
