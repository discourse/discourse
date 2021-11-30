import I18n from "I18n";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";

discourseModule("Unit | Controller | create-account", function () {
  test("basicUsernameValidation", function (assert) {
    const testInvalidUsername = (username, expectedReason) => {
      const controller = this.getController("create-account");
      controller.set("accountUsername", username);

      let validation = controller.basicUsernameValidation(username);
      assert.ok(validation.failed, "username should be invalid: " + username);
      assert.strictEqual(
        validation.reason,
        expectedReason,
        "username validation reason: " + username + ", " + expectedReason
      );
    };

    testInvalidUsername("", null);
    testInvalidUsername("x", I18n.t("user.username.too_short"));
    testInvalidUsername(
      "123456789012345678901",
      I18n.t("user.username.too_long")
    );

    const controller = this.getController("create-account", {
      accountUsername: "porkchops",
      prefilledUsername: "porkchops",
    });

    let validation = controller.basicUsernameValidation("porkchops");
    assert.ok(validation.ok, "Prefilled username is valid");
    assert.strictEqual(
      validation.reason,
      I18n.t("user.username.prefilled"),
      "Prefilled username is valid"
    );
  });

  test("passwordValidation", function (assert) {
    const controller = this.getController("create-account");

    controller.set("authProvider", "");
    controller.set("accountEmail", "pork@chops.com");
    controller.set("accountUsername", "porkchops");
    controller.set("prefilledUsername", "porkchops");
    controller.set("accountPassword", "b4fcdae11f9167");

    assert.strictEqual(
      controller.passwordValidation.ok,
      true,
      "Password is ok"
    );
    assert.strictEqual(
      controller.passwordValidation.reason,
      I18n.t("user.password.ok"),
      "Password is valid"
    );

    const testInvalidPassword = (password, expectedReason) => {
      controller.set("accountPassword", password);

      assert.strictEqual(
        controller.passwordValidation.failed,
        true,
        "password should be invalid: " + password
      );
      assert.strictEqual(
        controller.passwordValidation.reason,
        expectedReason,
        "password validation reason: " + password + ", " + expectedReason
      );
    };

    testInvalidPassword("", null);
    testInvalidPassword("x", I18n.t("user.password.too_short"));
    testInvalidPassword("porkchops", I18n.t("user.password.same_as_username"));
    testInvalidPassword(
      "pork@chops.com",
      I18n.t("user.password.same_as_email")
    );
  });

  test("authProviderDisplayName", function (assert) {
    const controller = this.getController("create-account");

    assert.strictEqual(
      controller.authProviderDisplayName("facebook"),
      I18n.t("login.facebook.name"),
      "provider name is translated correctly"
    );

    assert.strictEqual(
      controller.authProviderDisplayName("idontexist"),
      "idontexist",
      "provider name falls back if not found"
    );
  });
});
