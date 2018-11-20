import UserBadge from "discourse/models/user-badge";
import badgeFixtures from "fixtures/user-badges";

QUnit.module("model:user-badge");

QUnit.test("createFromJson single", assert => {
  const userBadge = UserBadge.createFromJson(badgeFixtures["/user_badges"]);
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

QUnit.test("createFromJson array", assert => {
  const userBadges = UserBadge.createFromJson(
    badgeFixtures["/user-badges/:username"]
  );
  assert.ok(Array.isArray(userBadges), "returns an array");
  assert.equal(
    userBadges[0].get("granted_by"),
    null,
    "granted_by reference is not set when null"
  );
});

QUnit.test("findByUsername", assert => {
  return UserBadge.findByUsername("anne3").then(function(badges) {
    assert.ok(Array.isArray(badges), "returns an array");
  });
});

QUnit.test("findByBadgeId", assert => {
  return UserBadge.findByBadgeId(880).then(function(badges) {
    assert.ok(Array.isArray(badges), "returns an array");
  });
});

QUnit.test("grant", assert => {
  return UserBadge.grant(1, "username").then(function(userBadge) {
    assert.ok(!Array.isArray(userBadge), "does not return an array");
  });
});

QUnit.test("revoke", assert => {
  assert.expect(0);
  const userBadge = UserBadge.create({ id: 1 });
  return userBadge.revoke();
});
