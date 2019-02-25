moduleFor("component:group-membership-button");

QUnit.test("canJoinGroup", function(assert) {
  this.subject().setProperties({
    model: { public_admission: false, is_group_user: true }
  });

  assert.equal(
    this.subject().get("canJoinGroup"),
    false,
    "can't join group if public_admission is false"
  );

  this.subject().set("model.public_admission", true);

  assert.equal(
    this.subject().get("canJoinGroup"),
    false,
    "can't join group if user is already in the group"
  );

  this.subject().set("model.is_group_user", false);

  assert.equal(
    this.subject().get("canJoinGroup"),
    true,
    "allowed to join group"
  );
});

QUnit.test("canLeaveGroup", function(assert) {
  this.subject().setProperties({
    model: { public_exit: false, is_group_user: false }
  });

  assert.equal(
    this.subject().get("canLeaveGroup"),
    false,
    "can't leave group if public_exit is false"
  );

  this.subject().set("model.public_exit", true);

  assert.equal(
    this.subject().get("canLeaveGroup"),
    false,
    "can't leave group if user is not in the group"
  );

  this.subject().set("model.is_group_user", true);

  assert.equal(
    this.subject().get("canLeaveGroup"),
    true,
    "allowed to leave group"
  );
});

QUnit.test("canRequestMembership", function(assert) {
  this.subject().setProperties({
    model: { allow_membership_requests: true, is_group_user: true }
  });

  assert.equal(
    this.subject().get("canRequestMembership"),
    false,
    "can't request for membership if user is already in the group"
  );

  this.subject().set("model.is_group_user", false);

  assert.equal(
    this.subject().get("canRequestMembership"),
    true,
    "allowed to request for group membership"
  );
});

QUnit.test("userIsGroupUser", function(assert) {
  this.subject().setProperties({
    model: { is_group_user: true }
  });

  assert.equal(this.subject().get("userIsGroupUser"), true);

  this.subject().set("model.is_group_user", false);

  assert.equal(this.subject().get("userIsGroupUser"), false);

  this.subject().set("model.is_group_user", null);

  assert.equal(this.subject().get("userIsGroupUser"), false);
});
