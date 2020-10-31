import EmberObject from "@ember/object";
import { mapRoutes } from "discourse/mapping-router";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";

discourseModule("Unit | Controller | avatar-selector", function (hooks) {
  hooks.beforeEach(function () {
    this.registry.register("router:main", mapRoutes());
  });

  test("avatarTemplate", function (assert) {
    const avatarSelectorController = this.owner.lookup(
      "controller:avatar-selector"
    );

    const user = EmberObject.create({
      avatar_template: "avatar",
      system_avatar_template: "system",
      gravatar_avatar_template: "gravatar",

      system_avatar_upload_id: 1,
      gravatar_avatar_upload_id: 2,
      custom_avatar_upload_id: 3,
    });

    avatarSelectorController.setProperties({ user });

    user.set("avatar_template", "system");
    assert.equal(
      avatarSelectorController.get("selectedUploadId"),
      1,
      "we are using system by default"
    );

    user.set("avatar_template", "gravatar");
    assert.equal(
      avatarSelectorController.get("selectedUploadId"),
      2,
      "we are using gravatar when set"
    );

    user.set("avatar_template", "avatar");
    assert.equal(
      avatarSelectorController.get("selectedUploadId"),
      3,
      "we are using custom when set"
    );
  });
});
