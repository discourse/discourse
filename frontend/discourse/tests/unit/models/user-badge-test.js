import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import UserBadge from "discourse/models/user-badge";
import badgeFixtures from "discourse/tests/fixtures/user-badges";

module("Unit | Model | user-badge", function (hooks) {
  setupTest(hooks);

  test("createFromJson single", function (assert) {
    const userBadge = UserBadge.createFromJson(
      cloneJSON(badgeFixtures["/user_badges"])
    );
    assert.false(Array.isArray(userBadge), "does not return an array");
    assert.strictEqual(
      userBadge.badge.name,
      "Badge 2",
      "badge reference is set"
    );
    assert.strictEqual(
      userBadge.badge.badge_type.name,
      "Silver 2",
      "badge.badge_type reference is set"
    );
    assert.strictEqual(
      userBadge.granted_by.username,
      "anne3",
      "granted_by reference is set"
    );
  });

  test("createFromJson array", function (assert) {
    const userBadges = UserBadge.createFromJson(
      cloneJSON(badgeFixtures["/user-badges/:username"])
    );
    assert.true(Array.isArray(userBadges), "returns an array");
    assert.strictEqual(
      userBadges[0].granted_by,
      undefined,
      "granted_by reference is not set when null"
    );
  });

  test("wraps sideloaded topic and user in their model classes", function (assert) {
    const payload = cloneJSON(badgeFixtures["/user_badges"]);
    payload.user_badge.user_id = 13470;
    payload.user_badge.topic_id = 280;
    payload.topics = [
      { id: 280, title: "A granting topic", slug: "a-granting-topic" },
    ];

    const userBadge = UserBadge.createFromJson(payload);

    assert.strictEqual(
      userBadge.topic.url,
      "/t/a-granting-topic/280",
      "topic exposes `Topic` getters"
    );
    assert.strictEqual(
      userBadge.user.path,
      "/u/anne3",
      "user exposes `User` getters"
    );

    const topic = userBadge.topic;
    assert.strictEqual(userBadge.topic, topic, "reuses the same wrapper");
  });

  test("keeps sideloads that a later payload doesn't carry", function (assert) {
    const withTopic = cloneJSON(badgeFixtures["/user_badges"]);
    withTopic.user_badge.topic_id = 280;
    withTopic.topics = [
      { id: 280, title: "A granting topic", slug: "a-granting-topic" },
    ];
    UserBadge.createFromJson(withTopic);

    // `/user-badges/:username` sends `topic_id` but no `topics` sideload.
    const withoutTopic = cloneJSON(badgeFixtures["/user_badges"]);
    withoutTopic.user_badge.topic_id = 280;
    const userBadge = UserBadge.createFromJson(withoutTopic);

    assert.strictEqual(
      userBadge.topic.url,
      "/t/a-granting-topic/280",
      "the topic from the earlier payload survives"
    );
  });

  test("findByUsername", async function (assert) {
    const badges = await UserBadge.findByUsername("anne3");
    assert.true(Array.isArray(badges), "returns an array");
  });

  test("findByBadgeId", async function (assert) {
    const badges = await UserBadge.findByBadgeId(880);
    assert.true(Array.isArray(badges), "returns an array");
  });

  test("grant", async function (assert) {
    const userBadge = await UserBadge.grant(1, "username");
    assert.false(Array.isArray(userBadge), "does not return an array");
  });

  test("revoke", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const userBadge = store.createRecord("user-badge", { id: 1 });
    const result = await userBadge.revoke();
    assert.deepEqual(result, { success: true });
  });

  test("favorite", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const userBadge = store.createRecord("user-badge", { id: 1 });
    assert.strictEqual(userBadge.is_favorite, undefined);

    await userBadge.favorite();
    assert.true(userBadge.is_favorite);
  });
});
