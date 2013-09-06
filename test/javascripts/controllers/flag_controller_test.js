var buildPost = function(args) {
  return Discourse.Post.create(_.merge({
    id: 1,
    can_delete: true,
    version: 1
  }, args || {}));
};

var buildAdminUser = function(args) {
  return Discourse.AdminUser.create(_.merge({
    id: 11,
    username: 'urist'
  }, args || {}));
};

module("Discourse.FlagController canDeleteSpammer");

test("canDeleteSpammer not staff", function(){
  var flagController = testController(Discourse.FlagController, buildPost());
  this.stub(Discourse.User, 'currentProp').withArgs('staff').returns(false);
  flagController.set('selected', Discourse.PostActionType.create({name_key: 'spam'}));
  equal(flagController.get('canDeleteSpammer'), false, 'false if current user is not staff');
});

var canDeleteSpammer = function(test, postActionType, expected, testName) {
  test.flagController.set('selected', Discourse.PostActionType.create({name_key: postActionType}));
  equal(test.flagController.get('canDeleteSpammer'), expected, testName);
};

test("canDeleteSpammer spam not selected", function(){
  this.stub(Discourse.User, 'currentProp').withArgs('staff').returns(true);
  this.flagController = testController(Discourse.FlagController, buildPost());
  this.flagController.set('userDetails', buildAdminUser({can_delete_all_posts: true, can_be_deleted: true}));
  canDeleteSpammer(this, 'off_topic', false, 'false if current user is staff, but selected is off_topic');
  canDeleteSpammer(this, 'inappropriate', false, 'false if current user is staff, but selected is inappropriate');
  canDeleteSpammer(this, 'notify_user', false, 'false if current user is staff, but selected is notify_user');
  canDeleteSpammer(this, 'notify_moderators', false, 'false if current user is staff, but selected is notify_moderators');
});

test("canDeleteSpammer spam selected", function(){
  this.stub(Discourse.User, 'currentProp').withArgs('staff').returns(true);
  this.flagController = testController(Discourse.FlagController, buildPost());

  this.flagController.set('userDetails', buildAdminUser({can_delete_all_posts: true, can_be_deleted: true}));
  canDeleteSpammer(this, 'spam', true, 'true if current user is staff, selected is spam, posts and user can be deleted');

  this.flagController.set('userDetails', buildAdminUser({can_delete_all_posts: false, can_be_deleted: true}));
  canDeleteSpammer(this, 'spam', false, 'false if current user is staff, selected is spam, posts cannot be deleted');

  this.flagController.set('userDetails', buildAdminUser({can_delete_all_posts: true, can_be_deleted: false}));
  canDeleteSpammer(this, 'spam', false, 'false if current user is staff, selected is spam, user cannot be deleted');

  this.flagController.set('userDetails', buildAdminUser({can_delete_all_posts: false, can_be_deleted: false}));
  canDeleteSpammer(this, 'spam', false, 'false if current user is staff, selected is spam, user cannot be deleted');
});
