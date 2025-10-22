import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import KeyValueStore from "discourse/lib/key-value-store";
import {
  RECENT_ANY_REACTIONS_STORE_KEY,
  RECENT_ANY_REACTIONS_STORE_NAMESPACE,
} from "discourse/services/recent-any-reactions-store";

module("Unit | Service | recent-any-reactions-store", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.recentAnyReactionsStore = getOwner(this).lookup(
      "service:recent-any-reactions-store"
    );
  });

  hooks.afterEach(function () {
    this.recentAnyReactionsStore.clearRecentReactions();
  });

  test(".trackAnyReaction", function (assert) {
    this.recentAnyReactionsStore.trackAnyReaction("grinning");
    const storedReactions = new KeyValueStore(
      RECENT_ANY_REACTIONS_STORE_NAMESPACE
    ).getObject(RECENT_ANY_REACTIONS_STORE_KEY);

    assert.deepEqual(this.recentAnyReactionsStore.getRecentAnyReactions(), [
      "grinning",
    ]);
    assert.deepEqual(
      storedReactions,
      ["grinning"],
      "it persists the tracked reactions"
    );
  });

  test("limits the maximum number of tracked reactions", function (assert) {
    // Set a low max count for testing
    this.recentAnyReactionsStore.siteSettings.discourse_reactions_recent_any_reactions_count = 3;
    
    this.recentAnyReactionsStore.trackAnyReaction("emoji1");
    this.recentAnyReactionsStore.trackAnyReaction("emoji2");
    this.recentAnyReactionsStore.trackAnyReaction("emoji3");
    this.recentAnyReactionsStore.trackAnyReaction("emoji4");

    assert.strictEqual(
      this.recentAnyReactionsStore.getRecentAnyReactions().length,
      3
    );
    assert.deepEqual(this.recentAnyReactionsStore.getRecentAnyReactions(), [
      "emoji4",
      "emoji3",
      "emoji2",
    ]);
  });

  test("moves existing reaction to front when tracked again", function (assert) {
    this.recentAnyReactionsStore.trackAnyReaction("emoji1");
    this.recentAnyReactionsStore.trackAnyReaction("emoji2");
    this.recentAnyReactionsStore.trackAnyReaction("emoji1");

    assert.deepEqual(this.recentAnyReactionsStore.getRecentAnyReactions(), [
      "emoji1",
      "emoji2",
    ]);
  });

  test(".clearRecentReactions", function (assert) {
    this.recentAnyReactionsStore.trackAnyReaction("grinning");
    this.recentAnyReactionsStore.trackAnyReaction("cat");

    this.recentAnyReactionsStore.clearRecentReactions();

    assert.deepEqual(this.recentAnyReactionsStore.getRecentAnyReactions(), []);
  });

  test("normalizes emoji codes", function (assert) {
    this.recentAnyReactionsStore.trackAnyReaction(":grinning:");
    this.recentAnyReactionsStore.trackAnyReaction("cat");

    assert.deepEqual(this.recentAnyReactionsStore.getRecentAnyReactions(), [
      "cat",
      "grinning",
    ]);
  });
});