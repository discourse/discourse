moduleFor("controller:admin-group");

test("disablePublicSetting", function() {
  this.subject().setProperties({
    model: { visible: false, allow_membership_requests: false }
  });

  equal(this.subject().get("disablePublicSetting"), true, "it should disable setting");

  this.subject().set("model.visible", true);

  equal(this.subject().get("disablePublicSetting"), false, "it should enable setting");

  this.subject().set("model.allow_membership_requests", true);

  equal(this.subject().get("disablePublicSetting"), true, "it should disable setting");
});

test("disableMembershipRequestSetting", function() {
  this.subject().setProperties({
    model: { visible: false, public: false, canEveryoneMention: true }
  });

  equal(this.subject().get("disableMembershipRequestSetting"), true, "it should disable setting");

  this.subject().set("model.visible", true);

  equal(this.subject().get("disableMembershipRequestSetting"), false, "it should enable setting");

  this.subject().set("model.public", true);

  equal(this.subject().get("disableMembershipRequestSetting"), true, "it should disalbe setting");
});
