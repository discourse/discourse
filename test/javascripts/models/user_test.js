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
