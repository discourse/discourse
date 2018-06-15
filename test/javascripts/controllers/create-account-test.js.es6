import { mapRoutes } from "discourse/mapping-router";

moduleFor("controller:create-account", "controller:create-account", {
  beforeEach() {
    this.registry.register("router:main", mapRoutes());
  },
  needs: ["controller:modal", "controller:login"]
});

QUnit.test("basicUsernameValidation", function(assert) {
  var subject = this.subject;

  var testInvalidUsername = function(username, expectedReason) {
    var controller = subject({ siteSettings: Discourse.SiteSettings });
    controller.set("accountUsername", username);
    assert.equal(
      controller.get("basicUsernameValidation.failed"),
      true,
      "username should be invalid: " + username
    );
    assert.equal(
      controller.get("basicUsernameValidation.reason"),
      expectedReason,
      "username validation reason: " + username + ", " + expectedReason
    );
  };

  testInvalidUsername("", undefined);
  testInvalidUsername("x", I18n.t("user.username.too_short"));
  testInvalidUsername(
    "123456789012345678901",
    I18n.t("user.username.too_long")
  );

  var controller = subject({ siteSettings: Discourse.SiteSettings });
  controller.set("accountUsername", "porkchops");
  controller.set("prefilledUsername", "porkchops");
  assert.equal(
    controller.get("basicUsernameValidation.ok"),
    true,
    "Prefilled username is valid"
  );
  assert.equal(
    controller.get("basicUsernameValidation.reason"),
    I18n.t("user.username.prefilled"),
    "Prefilled username is valid"
  );
});

QUnit.test("passwordValidation", function(assert) {
  var subject = this.subject;

  var controller = subject({ siteSettings: Discourse.SiteSettings });
  controller.set("passwordRequired", true);
  controller.set("accountEmail", "pork@chops.com");
  controller.set("accountUsername", "porkchops");
  controller.set("prefilledUsername", "porkchops");

  controller.set("accountPassword", "b4fcdae11f9167");
  assert.equal(controller.get("passwordValidation.ok"), true, "Password is ok");
  assert.equal(
    controller.get("passwordValidation.reason"),
    I18n.t("user.password.ok"),
    "Password is valid"
  );

  var testInvalidPassword = function(password, expectedReason) {
    var c = subject({ siteSettings: Discourse.SiteSettings });
    c.set("accountPassword", password);
    assert.equal(
      c.get("passwordValidation.failed"),
      true,
      "password should be invalid: " + password
    );
    assert.equal(
      c.get("passwordValidation.reason"),
      expectedReason,
      "password validation reason: " + password + ", " + expectedReason
    );
  };

  testInvalidPassword("", undefined);
  testInvalidPassword("x", I18n.t("user.password.too_short"));
  testInvalidPassword("porkchops", I18n.t("user.password.same_as_username"));
  testInvalidPassword("pork@chops.com", I18n.t("user.password.same_as_email"));
});
