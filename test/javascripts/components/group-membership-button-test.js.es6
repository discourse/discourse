moduleFor('component:group-membership-button');

QUnit.test('canJoinGroup', function(assert) {
  this.subject().setProperties({
    model: { public: false }
  });

  assert.equal(this.subject().get("canJoinGroup"), false, "non public group cannot be joined");

  this.subject().set("model.public", true);

  assert.equal(this.subject().get("canJoinGroup"), true, "public group can be joined");

  this.subject().setProperties({ currentUser: null, model: { public: true } });

  assert.equal(this.subject().get("canJoinGroup"), true, "can't join group when not logged in");
});

QUnit.test('userIsGroupUser', function(assert) {
  this.subject().setProperties({
    model: { is_group_user: true }
  });

  assert.equal(this.subject().get('userIsGroupUser'), true);

  this.subject().set('model.is_group_user', false);

  assert.equal(this.subject().get('userIsGroupUser'), false);

  this.subject().setProperties({ model: { id: 1 }, groupUserIds: [1] });

  assert.equal(this.subject().get('userIsGroupUser'), true);

  this.subject().set('groupUserIds', [3]);

  assert.equal(this.subject().get('userIsGroupUser'), false);

  this.subject().set('groupUserIds', undefined);

  assert.equal(this.subject().get('userIsGroupUser'), false);

  this.subject().setProperties({
    groupUserIds: [1, 3],
    model: { id: 1, is_group_user: false }
  });

  assert.equal(this.subject().get('userIsGroupUser'), false);
});
