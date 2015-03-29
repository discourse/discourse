moduleFor("controller:avatar-selector", "controller:avatar-selector", {
  needs: ['controller:modal']
});

test("avatarTemplate", function() {
  const avatarSelectorController = this.subject();

  avatarSelectorController.setProperties({
    selected: "system",
    system_avatar_upload_id:1,
    gravatar_avatar_upload_id:2,
    custom_avatar_upload_id: 3
  });

  equal(avatarSelectorController.get("selectedUploadId"), 1, "we are using system by default");

  avatarSelectorController.set('selected', 'gravatar');
  equal(avatarSelectorController.get("selectedUploadId"), 2, "we are using gravatar when set");

  avatarSelectorController.set("selected", "custom");
  equal(avatarSelectorController.get("selectedUploadId"), 3, "we are using custom when set");
});
