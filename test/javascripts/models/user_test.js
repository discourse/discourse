module("Discourse.User");

test('staff', function(){
  var user = Discourse.User.create({id: 1, username: 'eviltrout'});

  ok(!user.get('staff'), "user is not staff");

  user.toggleProperty('moderator');
  ok(user.get('staff'), "moderators are staff");

  user.setProperties({moderator: false, admin: true});
  ok(user.get('staff'), "admins are staff");
});

test('searchContext', function() {
  var user = Discourse.User.create({id: 1, username: 'EvilTrout'});

  deepEqual(user.get('searchContext'), {type: 'user', id: 'eviltrout', user: user}, "has a search context");
});

test("isAllowedToUploadAFile", function() {
  var user = Discourse.User.create({ trust_level: 0, admin: true });
  ok(user.isAllowedToUploadAFile("image"), "admin can always upload a file");

  user.setProperties({ admin: false, moderator: true });
  ok(user.isAllowedToUploadAFile("image"), "moderator can always upload a file");
});

test("homepage when top is disabled", function() {
  var newUser = Discourse.User.create({ trust_level: 0, last_seen_at: moment() }),
      oldUser = Discourse.User.create({ trust_level: 1, last_seen_at: moment() }),
      defaultHomepage = Discourse.Utilities.defaultHomepage();

  Discourse.SiteSettings.top_menu = "latest";

  equal(newUser.get("homepage"), defaultHomepage, "new user's homepage is default when top is disabled");
  equal(oldUser.get("homepage"), defaultHomepage, "old user's homepage is default when top is disabled");

  oldUser.set("last_seen_at", moment().subtract('month', 2));
  equal(oldUser.get("homepage"), defaultHomepage, "long-time-no-see old user's homepage is default when top is disabled");
});

test("homepage when top is enabled", function() {
  var newUser = Discourse.User.create({ trust_level: 0, last_seen_at: moment() }),
      oldUser = Discourse.User.create({ trust_level: 1, last_seen_at: moment() }),
      defaultHomepage = Discourse.Utilities.defaultHomepage();

  Discourse.SiteSettings.top_menu = "latest|top";

  equal(newUser.get("homepage"), "top", "new user's homepage is top when top is enabled");
  equal(oldUser.get("homepage"), defaultHomepage, "old user's homepage is default when top is enabled");

  oldUser.set("last_seen_at", moment().subtract('month', 2));
  equal(oldUser.get("homepage"), "top", "long-time-no-see old user's homepage is top when top is enabled");
});


asyncTestDiscourse("findByUsername", function() {
  expect(3);

  Discourse.User.findByUsername('eviltrout').then(function (user) {
    present(user);
    equal(user.get('username'), 'eviltrout', 'it has the correct username');
    equal(user.get('name'), 'Robin Ward', 'it has the full name since it has details');
    start();
  });
});
