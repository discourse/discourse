import createStore from 'helpers/create-store';

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

moduleFor("controller:flag", "controller:flag", {
  needs: ['controller:modal']
});

test("canDeleteSpammer not staff", function(){
  const store = createStore();

  var flagController = this.subject({ model: buildPost() });
  sandbox.stub(Discourse.User, 'currentProp').withArgs('staff').returns(false);

  const spamFlag = store.createRecord('post-action-type', {name_key: 'spam'});
  flagController.set('selected', spamFlag);
  equal(flagController.get('canDeleteSpammer'), false, 'false if current user is not staff');
});

var canDeleteSpammer = function(flagController, postActionType, expected, testName) {
  const store = createStore();
  const flag = store.createRecord('post-action-type', {name_key: postActionType});
  flagController.set('selected', flag);

  equal(flagController.get('canDeleteSpammer'), expected, testName);
};

test("canDeleteSpammer spam not selected", function(){
  sandbox.stub(Discourse.User, 'currentProp').withArgs('staff').returns(true);
  var flagController = this.subject({ model: buildPost() });
  flagController.set('userDetails', buildAdminUser({can_delete_all_posts: true, can_be_deleted: true}));
  canDeleteSpammer(flagController, 'off_topic', false, 'false if current user is staff, but selected is off_topic');
  canDeleteSpammer(flagController, 'inappropriate', false, 'false if current user is staff, but selected is inappropriate');
  canDeleteSpammer(flagController, 'notify_user', false, 'false if current user is staff, but selected is notify_user');
  canDeleteSpammer(flagController, 'notify_moderators', false, 'false if current user is staff, but selected is notify_moderators');
});

test("canDeleteSpammer spam selected", function(){
  sandbox.stub(Discourse.User, 'currentProp').withArgs('staff').returns(true);
  var flagController = this.subject({ model: buildPost() });
  flagController.set('userDetails', buildAdminUser({can_delete_all_posts: true, can_be_deleted: true}));
  canDeleteSpammer(flagController, 'spam', true, 'true if current user is staff, selected is spam, posts and user can be deleted');

  flagController.set('userDetails', buildAdminUser({can_delete_all_posts: false, can_be_deleted: true}));
  canDeleteSpammer(flagController, 'spam', false, 'false if current user is staff, selected is spam, posts cannot be deleted');

  flagController.set('userDetails', buildAdminUser({can_delete_all_posts: true, can_be_deleted: false}));
  canDeleteSpammer(flagController, 'spam', false, 'false if current user is staff, selected is spam, user cannot be deleted');

  flagController.set('userDetails', buildAdminUser({can_delete_all_posts: false, can_be_deleted: false}));
  canDeleteSpammer(flagController, 'spam', false, 'false if current user is staff, selected is spam, user cannot be deleted');
});
