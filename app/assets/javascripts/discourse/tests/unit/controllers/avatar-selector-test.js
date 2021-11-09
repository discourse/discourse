import EmberObject from "@ember/object";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import { registerRouter } from "discourse/mapping-router";
import { test } from "qunit";

discourseModule("Unit | Controller | avatar-selector", function (hooks) {
  hooks.beforeEach(function () {
    registerRouter(this.registry);
  });

  test("avatarTemplate", function (assert) {
    const user = EmberObject.create({
      avatar_template: "avatar",
      system_avatar_template: "system",
      gravatar_avatar_template: "gravatar",

      system_avatar_upload_id: 1,
      gravatar_avatar_upload_id: 2,
      custom_avatar_upload_id: 3,
    });
    const avatarSelectorController = this.getController("avatar-selector", {
      user,
    });

    user.set("avatar_template", "system");
    assert.strictEqual(
      avatarSelectorController.get("selectedUploadId"),
      1,
      "we are using system by default"
    );

    user.set("avatar_template", "gravatar");
    assert.strictEqual(
      avatarSelectorController.get("selectedUploadId"),
      2,
      "we are using gravatar when set"
    );

    user.set("avatar_template", "avatar");
    assert.strictEqual(
      avatarSelectorController.get("selectedUploadId"),
      3,
      "we are using custom when set"
    );
  });
});
