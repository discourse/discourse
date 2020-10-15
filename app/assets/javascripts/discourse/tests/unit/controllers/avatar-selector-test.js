import EmberObject from "@ember/object";
import { mapRoutes } from "discourse/mapping-router";
import { moduleFor } from "ember-qunit";
import { test } from "qunit";

moduleFor("controller:avatar-selector", "controller:avatar-selector", {
  beforeEach() {
    this.registry.register("router:main", mapRoutes());
  },
  needs: ["controller:modal"],
});

test("avatarTemplate", function (assert) {
  const avatarSelectorController = this.subject();

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
