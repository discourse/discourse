module("Discourse.UserBadge");

test('createFromJson single', function() {
  var json = {"badges":[{"id":874,"name":"Badge 2","description":null,"badge_type_id":7}],"badge_types":[{"id":7,"name":"Silver 2","color_hexcode":"#c0c0c0"}],"users":[{"id":13470,"username":"anne3","avatar_template":"//www.gravatar.com/avatar/a4151b1fd72089c54e2374565a87da7f.png?s={size}\u0026r=pg\u0026d=identicon"}],"user_badge":{"id":665,"granted_at":"2014-03-09T20:30:01.190-04:00","badge_id":874,"granted_by_id":13470}};

  var userBadge = Discourse.UserBadge.createFromJson(json);
  ok(!Array.isArray(userBadge), "does not return an array");
  equal(userBadge.get('badge.name'), "Badge 2", "badge reference is set");
  equal(userBadge.get('badge.badge_type.name'), "Silver 2", "badge.badge_type reference is set");
  equal(userBadge.get('granted_by.username'), "anne3", "granted_by reference is set");
});

test('createFromJson array', function() {
  var json = {"badges":[{"id":880,"name":"Badge 8","description":null,"badge_type_id":13}],"badge_types":[{"id":13,"name":"Silver 8","color_hexcode":"#c0c0c0"}],"users":[],"user_badges":[{"id":668,"granted_at":"2014-03-09T20:30:01.420-04:00","badge_id":880,"granted_by_id":null}]};

  var userBadges = Discourse.UserBadge.createFromJson(json);
  ok(Array.isArray(userBadges), "returns an array");
  equal(userBadges[0].get('granted_by'), null, "granted_by reference is not set when null");
});
