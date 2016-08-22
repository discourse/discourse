import Badge from 'discourse/models/badge';

module("model:badge");

test('newBadge', function() {
  const badge1 = Badge.create({name: "New Badge"}),
      badge2 = Badge.create({id: 1, name: "Old Badge"});
  ok(badge1.get('newBadge'), "badges without ids are new");
  ok(!badge2.get('newBadge'), "badges with ids are not new");
});


test('createFromJson array', function() {
  const badgesJson = {"badge_types":[{"id":6,"name":"Silver 1"}],"badges":[{"id":1126,"name":"Badge 1","description":null,"badge_type_id":6}]};

  const badges = Badge.createFromJson(badgesJson);

  ok(Array.isArray(badges), "returns an array");
  equal(badges[0].get('name'), "Badge 1", "badge details are set");
  equal(badges[0].get('badge_type.name'), "Silver 1", "badge_type reference is set");
});

test('createFromJson single', function() {
  const badgeJson = {"badge_types":[{"id":6,"name":"Silver 1"}],"badge":{"id":1126,"name":"Badge 1","description":null,"badge_type_id":6}};

  const badge = Badge.createFromJson(badgeJson);

  ok(!Array.isArray(badge), "does not returns an array");
});

test('updateFromJson', function() {
  const badgeJson = {"badge_types":[{"id":6,"name":"Silver 1"}],"badge":{"id":1126,"name":"Badge 1","description":null,"badge_type_id":6}};
  const badge = Badge.create({name: "Badge 1"});
  badge.updateFromJson(badgeJson);
  equal(badge.get('id'), 1126, "id is set");
  equal(badge.get('badge_type.name'), "Silver 1", "badge_type reference is set");
});

test('save', function() {
  expect(0);
  const badge = Badge.create({name: "New Badge", description: "This is a new badge.", badge_type_id: 1});
  return badge.save(["name", "description", "badge_type_id"]);
});

test('destroy', function() {
  expect(0);
  const badge = Badge.create({name: "New Badge", description: "This is a new badge.", badge_type_id: 1});
  badge.destroy();
  badge.set('id', 3);
  return badge.destroy();
});
