moduleFor("controller:admin-group", {
  needs: ['controller:adminGroupsType']
});

QUnit.test("disablePublicSetting", function(assert) {
  this.subject().setProperties({
    model: { visible: false, allow_membership_requests: false }
  });

  assert.equal(this.subject().get("disablePublicSetting"), true, "it should disable setting");

  this.subject().set("model.visible", true);

  assert.equal(this.subject().get("disablePublicSetting"), false, "it should enable setting");

  this.subject().set("model.allow_membership_requests", true);

  assert.equal(this.subject().get("disablePublicSetting"), true, "it should disable setting");
});

QUnit.test("disableMembershipRequestSetting", function(assert) {
  this.subject().setProperties({
    model: { visible: false, public: false, canEveryoneMention: true }
  });

  assert.equal(this.subject().get("disableMembershipRequestSetting"), true, "it should disable setting");

  this.subject().set("model.visible", true);

  assert.equal(this.subject().get("disableMembershipRequestSetting"), false, "it should enable setting");

  this.subject().set("model.public", true);

  assert.equal(this.subject().get("disableMembershipRequestSetting"), true, "it should disalbe setting");
});
