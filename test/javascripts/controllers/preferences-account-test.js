import EmberObject from "@ember/object";
moduleFor("controller:preferences/account");

QUnit.test("updating of associated accounts", function(assert) {
  const controller = this.subject({
    siteSettings: {
      enable_google_oauth2_logins: true
    },
    model: EmberObject.create({
      id: 70,
      second_factor_enabled: true,
      is_anonymous: true
    }),
    currentUser: EmberObject.create({
      id: 1234
    }),
    site: EmberObject.create({
      isMobileDevice: false
    })
  });

  assert.equal(controller.get("canUpdateAssociatedAccounts"), false);

  controller.set("model.second_factor_enabled", false);
  assert.equal(controller.get("canUpdateAssociatedAccounts"), false);

  controller.set("model.is_anonymous", false);
  assert.equal(controller.get("canUpdateAssociatedAccounts"), false);

  controller.set("model.id", 1234);
  assert.equal(controller.get("canUpdateAssociatedAccounts"), true);
});
