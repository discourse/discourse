import { getOwner } from "@ember/owner";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { i18n } from "discourse-i18n";

module("Unit | Component | create-account", function (hooks) {
  setupTest(hooks);

  test("basicUsernameValidation", function (assert) {
    const testInvalidUsername = (username, expectedReason) => {
      const component = this.owner
        .factoryFor("component:modal/create-account")
        .create({ model: { accountUsername: username } });

      const validation = component.basicUsernameValidation(username);
      assert.true(validation.failed, `username should be invalid: ${username}`);
      assert.strictEqual(
        validation.reason,
        expectedReason,
        `username validation reason: ${username}, ${expectedReason}`
      );
    };

    testInvalidUsername("", null);
    testInvalidUsername("x", i18n("user.username.too_short"));
    testInvalidUsername(
      "123456789012345678901",
      i18n("user.username.too_long")
    );

    const component = this.owner
      .factoryFor("component:modal/create-account")
      .create({ model: { accountUsername: "porkchops" } });
    component.set("prefilledUsername", "porkchops");

    const validation = component.basicUsernameValidation("porkchops");
    assert.true(validation.ok, "Prefilled username is valid");
    assert.strictEqual(
      validation.reason,
      i18n("user.username.prefilled"),
      "Prefilled username is valid"
    );
  });

  test("passwordValidation", async function (assert) {
    const component = this.owner
      .factoryFor("component:modal/create-account")
      .create({
        model: {
          accountEmail: "pork@chops.com",
          accountUsername: "porkchops123",
        },
      });

    component.set("prefilledUsername", "porkchops123");
    component.set("accountPassword", "b4fcdae11f9167");
    assert.true(component.passwordValidation.ok, "Password is ok");
    assert.strictEqual(
      component.passwordValidation.reason,
      i18n("user.password.ok"),
      "Password is valid"
    );

    const testInvalidPassword = (password, expectedReason) => {
      component.set("accountPassword", password);

      assert.true(
        component.passwordValidation.failed,
        `password should be invalid: ${password}`
      );
      assert.strictEqual(
        component.passwordValidation.reason,
        expectedReason,
        `password validation reason: ${password}, ${expectedReason}`
      );
    };

    const siteSettings = getOwner(this).lookup("service:site-settings");
    testInvalidPassword("", null);
    testInvalidPassword(
      "x",
      i18n("user.password.too_short", {
        count: siteSettings.min_password_length,
      })
    );
    testInvalidPassword("porkchops123", i18n("user.password.same_as_username"));
    testInvalidPassword("pork@chops.com", i18n("user.password.same_as_email"));

    // Wait for username check request to finish
    await settled();
  });

  test("authProviderDisplayName", function (assert) {
    const component = this.owner
      .factoryFor("component:modal/create-account")
      .create({ model: {} });

    assert.strictEqual(
      component.authProviderDisplayName("facebook"),
      i18n("login.facebook.name"),
      "provider name is translated correctly"
    );

    assert.strictEqual(
      component.authProviderDisplayName("does-not-exist"),
      "does-not-exist",
      "provider name falls back if not found"
    );
  });
});
