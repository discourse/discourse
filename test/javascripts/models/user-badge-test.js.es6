import UserBadge from 'discourse/models/user-badge';
import badgeFixtures from 'fixtures/user-badges';

module("model:user-badge");

test('createFromJson single', function() {
  const userBadge = UserBadge.createFromJson(badgeFixtures['/user_badges']);
  ok(!Array.isArray(userBadge), "does not return an array");
  equal(userBadge.get('badge.name'), "Badge 2", "badge reference is set");
  equal(userBadge.get('badge.badge_type.name'), "Silver 2", "badge.badge_type reference is set");
  equal(userBadge.get('granted_by.username'), "anne3", "granted_by reference is set");
});

test('createFromJson array', function() {
  const userBadges = UserBadge.createFromJson(badgeFixtures['/user-badges/:username']);
  ok(Array.isArray(userBadges), "returns an array");
  equal(userBadges[0].get('granted_by'), null, "granted_by reference is not set when null");
});

test('findByUsername', function() {
  return UserBadge.findByUsername("anne3").then(function(badges) {
    ok(Array.isArray(badges), "returns an array");
  });
});

test('findByBadgeId', function() {
  return UserBadge.findByBadgeId(880).then(function(badges) {
    ok(Array.isArray(badges), "returns an array");
  });
});

test('grant', function() {
  return UserBadge.grant(1, "username").then(function(userBadge) {
    ok(!Array.isArray(userBadge), "does not return an array");
  });
});

test('revoke', function() {
  expect(0);
  const userBadge = UserBadge.create({id: 1});
  return userBadge.revoke();
});
