import { module, test } from "qunit";
import { setupTest } from "ember-qunit";
import EmberObject from "@ember/object";

module("Unit | Controller | avatar-selector", function (hooks) {
  setupTest(hooks);

  test("avatarTemplate", function (assert) {
    const user = EmberObject.create({
      avatar_template: "avatar",
      system_avatar_template: "system",
      gravatar_avatar_template: "gravatar",

      system_avatar_upload_id: 1,
      gravatar_avatar_upload_id: 2,
      custom_avatar_upload_id: 3,
    });
    const controller = this.owner.lookup("controller:avatar-selector");
    controller.setProperties({ user });

    user.set("avatar_template", "system");
    assert.strictEqual(
      controller.selectedUploadId,
      1,
      "we are using system by default"
    );

    user.set("avatar_template", "gravatar");
    assert.strictEqual(
      controller.selectedUploadId,
      2,
      "we are using gravatar when set"
    );

    user.set("avatar_template", "avatar");
    assert.strictEqual(
      controller.selectedUploadId,
      3,
      "we are using custom when set"
    );
  });
});
