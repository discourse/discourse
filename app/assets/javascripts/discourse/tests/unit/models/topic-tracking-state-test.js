import { module, test } from "qunit";
import { getProperties } from "@ember/object";
import Category from "discourse/models/category";
import { NotificationLevels } from "discourse/lib/notification-levels";
import TopicTrackingState from "discourse/models/topic-tracking-state";
import User from "discourse/models/user";
import Topic from "discourse/models/topic";
import createStore from "discourse/tests/helpers/create-store";
import sinon from "sinon";

module("Unit | Model | topic-tracking-state", function (hooks) {
  hooks.beforeEach(function () {
    this.clock = sinon.useFakeTimers(new Date(2012, 11, 31, 12, 0).getTime());
  });

  hooks.afterEach(function () {
    this.clock.restore();
  });

  test("tag counts", function (assert) {
    const trackingState = TopicTrackingState.create();

    trackingState.loadStates([
      {
        topic_id: 1,
        last_read_post_number: null,
        tags: ["foo", "new"],
      },
      {
        topic_id: 2,
        last_read_post_number: null,
        tags: ["new"],
      },
      {
        topic_id: 3,
        last_read_post_number: null,
        tags: ["random"],
      },
      {
        topic_id: 4,
        last_read_post_number: 1,
        highest_post_number: 7,
        tags: ["unread"],
        notification_level: NotificationLevels.TRACKING,
      },
      {
        topic_id: 5,
        last_read_post_number: 1,
        highest_post_number: 7,
        tags: ["bar", "unread"],
        notification_level: NotificationLevels.TRACKING,
      },
      {
        topic_id: 6,
        last_read_post_number: 1,
        highest_post_number: 7,
        tags: null,
        notification_level: NotificationLevels.TRACKING,
      },
    ]);

    const states = trackingState.countTags(["new", "unread"]);

    assert.equal(states["new"].newCount, 2, "new counts");
    assert.equal(states["new"].unreadCount, 0, "new counts");
    assert.equal(states["unread"].unreadCount, 2, "unread counts");
    assert.equal(states["unread"].newCount, 0, "unread counts");
  });

  test("forEachTracked", function (assert) {
    const trackingState = TopicTrackingState.create();

    trackingState.loadStates([
      {
        topic_id: 1,
        last_read_post_number: null,
        tags: ["foo", "new"],
      },
      {
        topic_id: 2,
        last_read_post_number: null,
        tags: ["new"],
      },
      {
        topic_id: 3,
        last_read_post_number: null,
        tags: ["random"],
      },
      {
        topic_id: 4,
        last_read_post_number: 1,
        highest_post_number: 7,
        category_id: 7,
        tags: ["unread"],
        notification_level: NotificationLevels.TRACKING,
      },
      {
        topic_id: 5,
        last_read_post_number: 1,
        highest_post_number: 7,
        tags: ["bar", "unread"],
        category_id: 7,
        notification_level: NotificationLevels.TRACKING,
      },
      {
        topic_id: 6,
        last_read_post_number: 1,
        highest_post_number: 7,
        tags: null,
        notification_level: NotificationLevels.TRACKING,
      },
    ]);

    let randomUnread = 0,
      randomNew = 0,
      sevenUnread = 0,
      sevenNew = 0;

    trackingState.forEachTracked((topic, isNew, isUnread) => {
      if (topic.category_id === 7) {
        if (isNew) {
          sevenNew += 1;
        }
        if (isUnread) {
          sevenUnread += 1;
        }
      }

      if (topic.tags && topic.tags.indexOf("random") > -1) {
        if (isNew) {
          randomNew += 1;
        }
        if (isUnread) {
          randomUnread += 1;
        }
      }
    });

    assert.equal(randomNew, 1, "random new");
    assert.equal(randomUnread, 0, "random unread");
    assert.equal(sevenNew, 0, "seven unread");
    assert.equal(sevenUnread, 2, "seven unread");
  });

  test("sync - delayed new topics for backend list are removed", function (assert) {
    const trackingState = TopicTrackingState.create();
    trackingState.states["t111"] = { last_read_post_number: null };

    trackingState.updateSeen(111, 7);
    const list = {
      topics: [
        {
          highest_post_number: null,
          id: 111,
          unread: 10,
          new_posts: 10,
        },
      ],
    };

    trackingState.sync(list, "new");
    assert.equal(
      list.topics.length,
      0,
      "expect new topic to be removed as it was seen"
    );
  });

  test("sync - delayed unread topics for backend list are marked seen", function (assert) {
    const trackingState = TopicTrackingState.create();
    trackingState.states["t111"] = { last_read_post_number: null };

    trackingState.updateSeen(111, 7);
    const list = {
      topics: [
        Topic.create({
          highest_post_number: null,
          id: 111,
          unread: 10,
          new_posts: 10,
          unseen: true,
          prevent_sync: false,
        }),
      ],
    };

    trackingState.sync(list, "unread");
    assert.equal(
      list.topics[0].unseen,
      false,
      "expect unread topic to be marked as seen"
    );
    assert.equal(
      list.topics[0].prevent_sync,
      true,
      "expect unread topic to be marked as prevent_sync"
    );
  });

  test("sync - remove topic from state for performance if it is seen and has no unread or new posts", function (assert) {
    const trackingState = TopicTrackingState.create();
    trackingState.states["t111"] = { topic_id: 111 };

    const list = {
      topics: [
        Topic.create({
          id: 111,
          unseen: false,
          seen: true,
          unread: 0,
          new_posts: 0,
          prevent_sync: false,
        }),
      ],
    };

    trackingState.sync(list, "unread");
    assert.notOk(
      trackingState.states.hasOwnProperty("t111"),
      "expect state for topic 111 to be deleted"
    );
  });

  test("sync - updates state to match list topic for unseen and unread/new topics", function (assert) {
    const trackingState = TopicTrackingState.create();
    trackingState.states["t111"] = { topic_id: 111, last_read_post_number: 0 };
    trackingState.states["t222"] = { topic_id: 222, last_read_post_number: 1 };

    const list = {
      topics: [
        Topic.create({
          id: 111,
          unseen: true,
          seen: false,
          unread: 0,
          new_posts: 0,
          highest_post_number: 20,
          category: {
            id: 123,
            name: "test category",
          },
          tags: ["pending"],
        }),
        Topic.create({
          id: 222,
          unseen: false,
          seen: true,
          unread: 3,
          new_posts: 0,
          highest_post_number: 20,
        }),
      ],
    };

    trackingState.sync(list, "unread");

    let state111 = trackingState.findState(111);
    let state222 = trackingState.findState(222);
    assert.equal(
      state111.last_read_post_number,
      null,
      "unseen topics get last_read_post_number reset to null"
    );
    assert.propEqual(
      getProperties(state111, "highest_post_number", "tags", "category_id"),
      { highest_post_number: 20, tags: ["pending"], category_id: 123 },
      "highest_post_number, category, and tags are set for a topic"
    );
    assert.equal(
      state222.last_read_post_number,
      17,
      "last_read_post_number is highest_post_number - (unread + new)"
    );
  });

  test("sync - states missing from the topic list are updated based on the selected filter", function (assert) {
    const trackingState = TopicTrackingState.create();
    trackingState.states["t111"] = {
      topic_id: 111,
      last_read_post_number: 4,
      highest_post_number: 5,
      notification_level: NotificationLevels.TRACKING,
    };
    trackingState.states["t222"] = {
      topic_id: 222,
      last_read_post_number: null,
      seen: false,
      notification_level: NotificationLevels.TRACKING,
    };

    const list = {
      topics: [],
    };

    trackingState.sync(list, "unread");
    assert.equal(
      trackingState.findState(111).last_read_post_number,
      5,
      "last_read_post_number set to highest post number to pretend read"
    );

    trackingState.sync(list, "new");
    assert.equal(
      trackingState.findState(222).last_read_post_number,
      1,
      "last_read_post_number set to 1 to pretend not new"
    );
  });

  test("subscribe to category", function (assert) {
    const store = createStore();
    const darth = store.createRecord("category", { id: 1, slug: "darth" }),
      luke = store.createRecord("category", {
        id: 2,
        slug: "luke",
        parentCategory: darth,
      }),
      categoryList = [darth, luke];

    sinon.stub(Category, "list").returns(categoryList);

    const trackingState = TopicTrackingState.create();

    trackingState.trackIncoming("c/darth/1/l/latest");

    trackingState.notify({
      message_type: "new_topic",
      topic_id: 1,
      payload: { category_id: 2, topic_id: 1 },
    });
    trackingState.notify({
      message_type: "new_topic",
      topic_id: 2,
      payload: { category_id: 3, topic_id: 2 },
    });
    trackingState.notify({
      message_type: "new_topic",
      topic_id: 3,
      payload: { category_id: 1, topic_id: 3 },
    });

    assert.equal(
      trackingState.get("incomingCount"),
      2,
      "expect to properly track incoming for category"
    );

    trackingState.resetTracking();
    trackingState.trackIncoming("c/darth/luke/2/l/latest");

    trackingState.notify({
      message_type: "new_topic",
      topic_id: 1,
      payload: { category_id: 2, topic_id: 1 },
    });
    trackingState.notify({
      message_type: "new_topic",
      topic_id: 2,
      payload: { category_id: 3, topic_id: 2 },
    });
    trackingState.notify({
      message_type: "new_topic",
      topic_id: 3,
      payload: { category_id: 1, topic_id: 3 },
    });

    assert.equal(
      trackingState.get("incomingCount"),
      1,
      "expect to properly track incoming for subcategory"
    );
  });

  test("getSubCategoryIds", function (assert) {
    const store = createStore();
    const foo = store.createRecord("category", { id: 1, slug: "foo" });
    const bar = store.createRecord("category", {
      id: 2,
      slug: "bar",
      parent_category_id: foo.id,
    });
    const baz = store.createRecord("category", {
      id: 3,
      slug: "baz",
      parent_category_id: bar.id,
    });
    sinon.stub(Category, "list").returns([foo, bar, baz]);

    const trackingState = TopicTrackingState.create();
    assert.deepEqual(Array.from(trackingState.getSubCategoryIds(1)), [1, 2, 3]);
    assert.deepEqual(Array.from(trackingState.getSubCategoryIds(2)), [2, 3]);
    assert.deepEqual(Array.from(trackingState.getSubCategoryIds(3)), [3]);
  });

  test("countNew", function (assert) {
    const store = createStore();
    const foo = store.createRecord("category", {
      id: 1,
      slug: "foo",
    });
    const bar = store.createRecord("category", {
      id: 2,
      slug: "bar",
      parent_category_id: foo.id,
    });
    const baz = store.createRecord("category", {
      id: 3,
      slug: "baz",
      parent_category_id: bar.id,
    });
    const qux = store.createRecord("category", {
      id: 4,
      slug: "qux",
    });
    sinon.stub(Category, "list").returns([foo, bar, baz, qux]);

    let currentUser = User.create({
      username: "chuck",
      muted_category_ids: [4],
    });

    const trackingState = TopicTrackingState.create({ currentUser });

    assert.equal(trackingState.countNew(1), 0);
    assert.equal(trackingState.countNew(2), 0);
    assert.equal(trackingState.countNew(3), 0);

    trackingState.states["t112"] = {
      last_read_post_number: null,
      id: 112,
      notification_level: NotificationLevels.TRACKING,
      category_id: 2,
    };

    assert.equal(trackingState.countNew(1), 1);
    assert.equal(trackingState.countNew(1, undefined, true), 0);
    assert.equal(trackingState.countNew(1, "missing-tag"), 0);
    assert.equal(trackingState.countNew(2), 1);
    assert.equal(trackingState.countNew(3), 0);

    trackingState.states["t113"] = {
      last_read_post_number: null,
      id: 113,
      notification_level: NotificationLevels.TRACKING,
      category_id: 3,
      tags: ["amazing"],
    };

    assert.equal(trackingState.countNew(1), 2);
    assert.equal(trackingState.countNew(2), 2);
    assert.equal(trackingState.countNew(3), 1);
    assert.equal(trackingState.countNew(3, "amazing"), 1);
    assert.equal(trackingState.countNew(3, "missing"), 0);

    trackingState.states["t111"] = {
      last_read_post_number: null,
      id: 111,
      notification_level: NotificationLevels.TRACKING,
      category_id: 1,
    };

    assert.equal(trackingState.countNew(1), 3);
    assert.equal(trackingState.countNew(2), 2);
    assert.equal(trackingState.countNew(3), 1);

    trackingState.states["t115"] = {
      last_read_post_number: null,
      id: 115,
      category_id: 4,
    };
    assert.equal(trackingState.countNew(4), 0);
  });

  test("dismissNew", function (assert) {
    let currentUser = User.create({
      username: "chuck",
    });

    const trackingState = TopicTrackingState.create({ currentUser });

    trackingState.states["t112"] = {
      last_read_post_number: null,
      id: 112,
      notification_level: NotificationLevels.TRACKING,
      category_id: 1,
      is_seen: false,
      tags: ["foo"],
    };

    trackingState.dismissNewTopic({
      message_type: "dismiss_new",
      payload: { topic_ids: [112] },
    });
    assert.equal(trackingState.states["t112"].is_seen, true);
  });

  test("mute and unmute topic", function (assert) {
    let currentUser = User.create({
      username: "chuck",
      muted_category_ids: [],
    });

    const trackingState = TopicTrackingState.create({ currentUser });

    trackingState.trackMutedOrUnmutedTopic({
      topic_id: 1,
      message_type: "muted",
    });
    assert.equal(currentUser.muted_topics[0].topicId, 1);

    trackingState.trackMutedOrUnmutedTopic({
      topic_id: 2,
      message_type: "unmuted",
    });
    assert.equal(currentUser.unmuted_topics[0].topicId, 2);

    trackingState.pruneOldMutedAndUnmutedTopics();
    assert.equal(trackingState.isMutedTopic(1), true);
    assert.equal(trackingState.isUnmutedTopic(2), true);

    this.clock.tick(60000);
    trackingState.pruneOldMutedAndUnmutedTopics();
    assert.equal(trackingState.isMutedTopic(1), false);
    assert.equal(trackingState.isUnmutedTopic(2), false);
  });
});
