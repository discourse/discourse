import { currentUser } from "helpers/qunit-helpers";

moduleFor('component:group-membership-button');

test('canJoinGroup', function() {
  this.subject().setProperties({
    model: { public: false }
  });

  equal(this.subject().get("canJoinGroup"), false, "non public group cannot be joined");

  this.subject().set("model.public", true);

  equal(this.subject().get("canJoinGroup"), true, "public group can be joined");

  this.subject().setProperties({ currentUser: null, model: { public: true } });

  equal(this.subject().get("canJoinGroup"), true, "can't join group when not logged in");
});

test('canRequestMembership', function() {
  this.subject().setProperties({
    model: { allow_membership_requests: false, alias_level: 0 }
  });

  equal(this.subject().get('canRequestMembership'), false);

  this.subject().setProperties({
    currentUser: currentUser(), model: { allow_membership_requests: true, alias_level: 99 }
  });

  equal(this.subject().get('canRequestMembership'), true);

  this.subject().set("model.alias_level", 0);

  equal(this.subject().get('canRequestMembership'), false);
});

test('userIsGroupUser', function() {
  this.subject().setProperties({
    model: { is_group_user: true }
  });

  equal(this.subject().get('userIsGroupUser'), true);

  this.subject().set('model.is_group_user', false);

  equal(this.subject().get('userIsGroupUser'), false);

  this.subject().setProperties({ model: { id: 1 }, groupUserIds: [1] });

  equal(this.subject().get('userIsGroupUser'), true);

  this.subject().set('groupUserIds', [3]);

  equal(this.subject().get('userIsGroupUser'), false);

  this.subject().set('groupUserIds', undefined);

  equal(this.subject().get('userIsGroupUser'), false);
});
