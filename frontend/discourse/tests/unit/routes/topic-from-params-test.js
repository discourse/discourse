import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import TopicFromParams, {
  nestedQueryString,
} from "discourse/routes/topic/from-params";

module("Unit | Route | topic.from-params", function (hooks) {
  setupTest(hooks);

  test("opts out of the global route scroll manager", function (assert) {
    assert.deepEqual(TopicFromParams.prototype.buildRouteInfoMetadata(), {
      scrollOnTransition: false,
    });
  });

  test("encodes nested JSON query params", function (assert) {
    const query = nestedQueryString({
      sort: "new&track_visit=false",
      track_visit: true,
      context: "0&sort=old",
      skipped: null,
    });
    const parsed = new URLSearchParams(query);

    assert.strictEqual(parsed.get("sort"), "new&track_visit=false");
    assert.strictEqual(parsed.get("track_visit"), "true");
    assert.strictEqual(parsed.get("context"), "0&sort=old");
    assert.false(parsed.has("skipped"));
    assert.false(parsed.has("bad"), "does not allow query injection");
  });

  test("saves current nested topic before swapping topics", function (assert) {
    const route = this.owner.lookup("route:topic.from-params");
    const article = document.createElement("article");
    article.dataset.postNumber = "3";
    const wrapper = document.createElement("div");
    wrapper.className = "nested-post";
    wrapper.appendChild(article);
    document.body.appendChild(wrapper);

    let screenTrackStopped = 0;
    let screenTrackStarted = 0;

    Object.defineProperty(route, "appEvents", {
      value: { trigger() {} },
    });
    Object.defineProperty(route, "screenTrack", {
      value: {
        start() {
          screenTrackStarted += 1;
        },
        stop() {
          screenTrackStopped += 1;
        },
      },
    });

    const nestedController = {
      topic: { id: 1 },
      unsubscribeCount: 0,
      savedAnchor: null,
      saveToCache(anchor) {
        this.savedAnchor = anchor;
      },
      setProperties(properties) {
        Object.assign(this, properties);
      },
      subscribe() {},
      unsubscribe() {
        this.unsubscribeCount += 1;
      },
    };
    const topicController = {
      selectedPostIds: [1],
      set(key, value) {
        this[key] = value;
      },
      setProperties(properties) {
        Object.assign(this, properties);
      },
      subscribe() {},
    };
    const nextTopic = {
      id: 2,
      details: { set() {} },
      draft: null,
      highest_post_number: 3,
      last_read_post_number: 1,
      postStream: null,
    };

    route.controllerFor = (name) => {
      if (name === "nested") {
        return nestedController;
      }

      return topicController;
    };

    try {
      route.setupController(
        null,
        {
          _nested: {
            topic: nextTopic,
            contextMode: true,
            sort: "top",
          },
        },
        {}
      );

      assert.strictEqual(
        nestedController.savedAnchor.postNumber,
        3,
        "saves the previous nested topic cache with the current scroll anchor"
      );
      assert.strictEqual(
        nestedController.unsubscribeCount,
        1,
        "unsubscribes the previous nested topic once"
      );
      assert.strictEqual(
        screenTrackStopped,
        1,
        "stops screen tracking for the previous nested topic"
      );
      assert.strictEqual(
        nestedController.topic,
        nextTopic,
        "sets up the new nested topic"
      );
      assert.strictEqual(
        screenTrackStarted,
        1,
        "starts tracking the new topic"
      );
    } finally {
      wrapper.remove();
    }
  });
});
