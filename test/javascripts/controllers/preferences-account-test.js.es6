import EmberObject from "@ember/object";
moduleFor("controller:preferences/account");

QUnit.test("updating of associated accounts", function(assert) {
  const controller = this.subject({
    siteSettings: {
      enable_google_oauth2_logins: true
    },
    model: EmberObject.create({
      second_factor_enabled: true,
      is_anonymous: true
    }),
    site: EmberObject.create({
      isMobileDevice: false
    })
  });

  controller.set("canCheckEmails", false);

  assert.equal(controller.get("canUpdateAssociatedAccounts"), false);

  controller.set("model.second_factor_enabled", false);

  assert.equal(controller.get("canUpdateAssociatedAccounts"), false);

  controller.set("model.is_anonymous", false);

  assert.equal(controller.get("canUpdateAssociatedAccounts"), false);

  controller.set("canCheckEmails", true);

  assert.equal(controller.get("canUpdateAssociatedAccounts"), true);
});
