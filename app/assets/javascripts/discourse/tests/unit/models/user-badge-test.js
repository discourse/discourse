import { module, test } from "qunit";
import UserBadge from "discourse/models/user-badge";
import badgeFixtures from "discourse/tests/fixtures/user-badges";

module("Unit | Model | user-badge", function () {
  test("createFromJson single", function (assert) {
    const userBadge = UserBadge.createFromJson(
      JSON.parse(JSON.stringify(badgeFixtures["/user_badges"]))
    );
    assert.ok(!Array.isArray(userBadge), "does not return an array");
    assert.equal(
      userBadge.get("badge.name"),
      "Badge 2",
      "badge reference is set"
    );
    assert.equal(
      userBadge.get("badge.badge_type.name"),
      "Silver 2",
      "badge.badge_type reference is set"
    );
    assert.equal(
      userBadge.get("granted_by.username"),
      "anne3",
      "granted_by reference is set"
    );
  });

  test("createFromJson array", function (assert) {
    const userBadges = UserBadge.createFromJson(
      JSON.parse(JSON.stringify(badgeFixtures["/user-badges/:username"]))
    );
    assert.ok(Array.isArray(userBadges), "returns an array");
    assert.equal(
      userBadges[0].get("granted_by"),
      null,
      "granted_by reference is not set when null"
    );
  });

  test("findByUsername", async function (assert) {
    const badges = await UserBadge.findByUsername("anne3");
    assert.ok(Array.isArray(badges), "returns an array");
  });

  test("findByBadgeId", async function (assert) {
    const badges = await UserBadge.findByBadgeId(880);
    assert.ok(Array.isArray(badges), "returns an array");
  });

  test("grant", async function (assert) {
    const userBadge = await UserBadge.grant(1, "username");
    assert.ok(!Array.isArray(userBadge), "does not return an array");
  });

  test("revoke", async function (assert) {
    assert.expect(0);
    const userBadge = UserBadge.create({ id: 1 });
    await userBadge.revoke();
  });

  test("favorite", async function (assert) {
    const userBadge = UserBadge.create({ id: 1 });
    assert.notOk(userBadge.is_favorite);

    await userBadge.favorite();
    assert.ok(userBadge.is_favorite);
  });
});
