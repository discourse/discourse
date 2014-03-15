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

test("homepage", function() {
  var user = Discourse.User.create({ should_be_redirected_to_top: false });
  var defaultHomepage = Discourse.Utilities.defaultHomepage();

  equal(user.get("homepage"), defaultHomepage, "user's homepage is default when not redirected");

  user.set("should_be_redirected_to_top", true);

  equal(user.get("homepage"), "top", "user's homepage is top when redirected");
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
