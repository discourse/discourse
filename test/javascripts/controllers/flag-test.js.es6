import createStore from 'helpers/create-store';
import AdminUser from 'admin/models/admin-user';
import { mapRoutes } from 'discourse/mapping-router';

var buildPost = function(args) {
  return Discourse.Post.create(_.merge({
    id: 1,
    can_delete: true,
    version: 1
  }, args || {}));
};

var buildAdminUser = function(args) {
  return AdminUser.create(_.merge({
    id: 11,
    username: 'urist'
  }, args || {}));
};

moduleFor("controller:flag", "controller:flag", {
  beforeEach() {
    this.registry.register('router:main', mapRoutes());
  },
  needs: ['controller:modal']
});

QUnit.test("canDeleteSpammer not staff", function(assert) {
  const store = createStore();

  var flagController = this.subject({ model: buildPost() });
  sandbox.stub(Discourse.User, 'currentProp').withArgs('staff').returns(false);

  const spamFlag = store.createRecord('post-action-type', {name_key: 'spam'});
  flagController.set('selected', spamFlag);
  assert.equal(flagController.get('canDeleteSpammer'), false, 'false if current user is not staff');
});

var canDeleteSpammer = function(assert, flagController, postActionType, expected, testName) {
  const store = createStore();
  const flag = store.createRecord('post-action-type', {name_key: postActionType});
  flagController.set('selected', flag);

  assert.equal(flagController.get('canDeleteSpammer'), expected, testName);
};

QUnit.test("canDeleteSpammer spam not selected", function(assert) {
  sandbox.stub(Discourse.User, 'currentProp').withArgs('staff').returns(true);
  var flagController = this.subject({ model: buildPost() });
  flagController.set('userDetails', buildAdminUser({can_delete_all_posts: true, can_be_deleted: true}));
  canDeleteSpammer(assert, flagController, 'off_topic', false, 'false if current user is staff, but selected is off_topic');
  canDeleteSpammer(assert, flagController, 'inappropriate', false, 'false if current user is staff, but selected is inappropriate');
  canDeleteSpammer(assert, flagController, 'notify_user', false, 'false if current user is staff, but selected is notify_user');
  canDeleteSpammer(assert, flagController, 'notify_moderators', false, 'false if current user is staff, but selected is notify_moderators');
});

QUnit.test("canDeleteSpammer spam selected", function(assert) {
  sandbox.stub(Discourse.User, 'currentProp').withArgs('staff').returns(true);
  var flagController = this.subject({ model: buildPost() });
  flagController.set('userDetails', buildAdminUser({can_delete_all_posts: true, can_be_deleted: true}));
  canDeleteSpammer(assert, flagController, 'spam', true, 'true if current user is staff, selected is spam, posts and user can be deleted');

  flagController.set('userDetails', buildAdminUser({can_delete_all_posts: false, can_be_deleted: true}));
  canDeleteSpammer(assert, flagController, 'spam', false, 'false if current user is staff, selected is spam, posts cannot be deleted');

  flagController.set('userDetails', buildAdminUser({can_delete_all_posts: true, can_be_deleted: false}));
  canDeleteSpammer(assert, flagController, 'spam', false, 'false if current user is staff, selected is spam, user cannot be deleted');

  flagController.set('userDetails', buildAdminUser({can_delete_all_posts: false, can_be_deleted: false}));
  canDeleteSpammer(assert, flagController, 'spam', false, 'false if current user is staff, selected is spam, user cannot be deleted');
});

QUnit.test("canSendWarning not staff", function(assert) {
  const store = createStore();

  var flagController = this.subject({ model: buildPost() });
  sandbox.stub(Discourse.User, 'currentProp').withArgs('staff').returns(false);

  const notifyUserFlag = store.createRecord('post-action-type', {name_key: 'notify_user'});
  flagController.set('selected', notifyUserFlag);
  assert.equal(flagController.get('canSendWarning'), false, 'false if current user is not staff');
});

var canSendWarning = function(assert, flagController, postActionType, expected, testName) {
  const store = createStore();
  const flag = store.createRecord('post-action-type', {name_key: postActionType});
  flagController.set('selected', flag);

  assert.equal(flagController.get('canSendWarning'), expected, testName);
};

QUnit.test("canSendWarning notify_user not selected", function(assert) {
  sandbox.stub(Discourse.User, 'currentProp').withArgs('staff').returns(true);
  var flagController = this.subject({ model: buildPost() });
  canSendWarning(assert, flagController, 'off_topic', false, 'false if current user is staff, but selected is off_topic');
  canSendWarning(assert, flagController, 'inappropriate', false, 'false if current user is staff, but selected is inappropriate');
  canSendWarning(assert, flagController, 'spam', false, 'false if current user is staff, but selected is spam');
  canSendWarning(assert, flagController, 'notify_moderators', false, 'false if current user is staff, but selected is notify_moderators');
});

QUnit.test("canSendWarning notify_user selected", function(assert) {
  sandbox.stub(Discourse.User, 'currentProp').withArgs('staff').returns(true);
  var flagController = this.subject({ model: buildPost() });
  canSendWarning(assert, flagController, 'notify_user', true, 'true if current user is staff, selected is notify_user');
});
