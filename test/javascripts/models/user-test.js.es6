import User from 'discourse/models/user';
import Group from 'discourse/models/group';

module("model:user");

test('staff', function(){
  var user = User.create({id: 1, username: 'eviltrout'});

  ok(!user.get('staff'), "user is not staff");

  user.toggleProperty('moderator');
  ok(user.get('staff'), "moderators are staff");

  user.setProperties({moderator: false, admin: true});
  ok(user.get('staff'), "admins are staff");
});

test('searchContext', function() {
  var user = User.create({id: 1, username: 'EvilTrout'});

  deepEqual(user.get('searchContext'), {type: 'user', id: 'eviltrout', user: user}, "has a search context");
});

test("isAllowedToUploadAFile", function() {
  var user = User.create({ trust_level: 0, admin: true });
  ok(user.isAllowedToUploadAFile("image"), "admin can always upload a file");

  user.setProperties({ admin: false, moderator: true });
  ok(user.isAllowedToUploadAFile("image"), "moderator can always upload a file");
});

test('canMangeGroup', function() {
  let user = User.create({ admin: true });
  let group = Group.create({ automatic: true });

  equal(user.canManageGroup(group), false, "automatic groups cannot be managed.");

  group.set("automatic", false);

  equal(user.canManageGroup(group), true, "an admin should be able to manage the group");

  user.set('admin', false);
  group.setProperties({ is_group_owner: true });

  equal(user.canManageGroup(group), true, "a group owner should be able to manage the group");
});
