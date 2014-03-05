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

test("homepage when top is enabled and not enough topics", function() {
  var newUser = Discourse.User.create({ trust_level: 0, last_seen_at: moment() }),
      oldUser = Discourse.User.create({ trust_level: 1, last_seen_at: moment() }),
      defaultHomepage = Discourse.Utilities.defaultHomepage();

  Discourse.SiteSettings.top_menu = "latest|top";
  Discourse.Site.currentProp("has_enough_topic_to_redirect_to_top_page", false);

  equal(newUser.get("homepage"), defaultHomepage, "new user's homepage is default");
  equal(oldUser.get("homepage"), defaultHomepage, "old user's homepage is default");

  oldUser.set("last_seen_at", moment().subtract('month', 2));
  equal(oldUser.get("homepage"), defaultHomepage, "long-time-no-see old user's homepage is default");
});

test("homepage when top is enabled and has enough topics", function() {
  var newUser = Discourse.User.create({ trust_level: 0, last_seen_at: moment(), created_at: moment().subtract("day", 6) }),
      oldUser = Discourse.User.create({ trust_level: 1, last_seen_at: moment(), created_at: moment().subtract("month", 2) }),
      defaultHomepage = Discourse.Utilities.defaultHomepage();

  Discourse.SiteSettings.top_menu = "latest|top";
  Discourse.SiteSettings.redirect_new_users_to_top_page_duration = 7;
  Discourse.Site.currentProp("has_enough_topic_to_redirect_to_top_page", true);

  equal(newUser.get("homepage"), "top", "new user's homepage is top when top is enabled");
  equal(oldUser.get("homepage"), defaultHomepage, "old user's homepage is default when top is enabled");

  oldUser.set("last_seen_at", moment().subtract('month', 2));
  equal(oldUser.get("homepage"), "top", "long-time-no-see old user's homepage is top when top is enabled");
});

test("new user's homepage when top is enabled, there's enough topics and duration is over", function() {
  var newUser = Discourse.User.create({ trust_level: 0, last_seen_at: moment(), created_at: moment().subtract("month", 1) }),
      defaultHomepage = Discourse.Utilities.defaultHomepage();

  Discourse.SiteSettings.top_menu = "latest|top";
  Discourse.SiteSettings.redirect_new_users_to_top_page_duration = 7;
  Discourse.Site.currentProp("has_enough_topic_to_redirect_to_top_page", true);

  equal(newUser.get("homepage"), defaultHomepage, "new user's homepage is default when redirect duration is over");
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
