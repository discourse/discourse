import { mapRoutes } from "discourse/mapping-router";

moduleFor("controller:avatar-selector", "controller:avatar-selector", {
  beforeEach() {
    this.registry.register("router:main", mapRoutes());
  },
  needs: ["controller:modal"]
});

QUnit.test("avatarTemplate", function(assert) {
  const avatarSelectorController = this.subject();

  avatarSelectorController.setProperties({
    selected: "system",
    system_avatar_upload_id: 1,
    gravatar_avatar_upload_id: 2,
    custom_avatar_upload_id: 3
  });

  assert.equal(
    avatarSelectorController.get("selectedUploadId"),
    1,
    "we are using system by default"
  );

  avatarSelectorController.set("selected", "gravatar");
  assert.equal(
    avatarSelectorController.get("selectedUploadId"),
    2,
    "we are using gravatar when set"
  );

  avatarSelectorController.set("selected", "custom");
  assert.equal(
    avatarSelectorController.get("selectedUploadId"),
    3,
    "we are using custom when set"
  );
});
