import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { logIn } from "discourse/tests/helpers/qunit-helpers";

module("Unit | Service | filter-topic-tracking", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    logIn(this.owner);
    this.owner.lookup("service:current-user").set("unified_new_enabled", true);
    this.tracking = this.owner.lookup("service:topic-tracking-state");
    this.counts = this.owner.lookup("service:filter-topic-tracking");
    this.tracking.states.clear();
    this.tracking.loadStates([
      { topic_id: 1, last_read_post_number: null, created_in_new_period: true },
      {
        topic_id: 2,
        last_read_post_number: 1,
        highest_post_number: 3,
        notification_level: 2,
      },
      { topic_id: 3, last_read_post_number: null, created_in_new_period: true },
    ]);
  });

  test("counts response membership and reacts to reading", function (assert) {
    this.counts.update("status:open", [1, 2]);
    assert.strictEqual(
      this.counts.query,
      "status:open",
      "stores the submitted query"
    );
    assert.strictEqual(
      this.counts.newTopicsCount,
      1,
      "counts matching new topics"
    );
    assert.strictEqual(
      this.counts.newRepliesCount,
      1,
      "counts matching unread topics"
    );
    this.tracking.modifyStateProp(2, "last_read_post_number", 3);
    assert.strictEqual(
      this.counts.newRepliesCount,
      0,
      "reading updates the count"
    );
  });

  test("replaces membership on the next list load", function (assert) {
    this.counts.update("status:open", [1, 2]);
    this.tracking.loadStates([
      { topic_id: 4, last_read_post_number: null, created_in_new_period: true },
    ]);
    assert.strictEqual(
      this.counts.newTopicsCount,
      1,
      "new arrivals await a list load"
    );
    this.counts.update("status:closed", [3, 4]);
    assert.strictEqual(
      this.counts.newTopicsCount,
      2,
      "uses the new response membership"
    );
    assert.strictEqual(
      this.counts.newRepliesCount,
      0,
      "drops previous membership"
    );
  });

  test("distinguishes empty membership from omitted counts and clears on exit", function (assert) {
    this.counts.update("", []);
    assert.strictEqual(
      this.counts.newTopicsCount,
      0,
      "empty membership is zero"
    );
    this.counts.update("");
    assert.strictEqual(
      this.counts.newTopicsCount,
      undefined,
      "omitted membership hides counts"
    );
    this.counts.update("", [1]);
    this.counts.stop();
    assert.strictEqual(
      this.counts.newTopicsCount,
      undefined,
      "exit clears counts"
    );
    assert.strictEqual(this.counts.query, undefined, "exit clears the query");
  });
});
