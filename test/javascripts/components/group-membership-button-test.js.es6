moduleFor('component:group-membership-button');

QUnit.test('canJoinGroup', function(assert) {
  this.subject().setProperties({
    model: { public_admission: false, is_group_user: true }
  });

  assert.equal(
    this.subject().get("canJoinGroup"), false,
    "can't join group if public_admission is false"
  );

  this.subject().set("model.public_admission", true);

  assert.equal(
    this.subject().get("canJoinGroup"), false,
    "can't join group if user is already in the group"
  );

  this.subject().set("model.is_group_user", false);

  assert.equal(
    this.subject().get("canJoinGroup"), true,
    "allowed to join group"
  );
});

QUnit.test('canLeaveGroup', function(assert) {
  this.subject().setProperties({
    model: { public_exit: false, is_group_user: false }
  });

  assert.equal(
    this.subject().get("canLeaveGroup"), false,
    "can't leave group if public_exit is false"
  );

  this.subject().set("model.public_exit", true);

  assert.equal(
    this.subject().get("canLeaveGroup"), false,
    "can't leave group if user is not in the group"
  );

  this.subject().set("model.is_group_user", true);

  assert.equal(
    this.subject().get("canLeaveGroup"), true,
    "allowed to leave group"
  );
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
