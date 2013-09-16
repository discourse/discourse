var avatarSelector = Em.Object.create({
  use_uploaded_avatar: false,
  gravatar_template: "//www.gravatar.com/avatar/c6e17f2ae2a215e87ff9e878a4e63cd9.png?s={size}&r=pg&d=identicon",
  uploaded_avatar_template: "//cdn.discourse.org/uploads/meta_discourse/avatars/093/607/185cff113e/{size}.jpg"
});

module("Discourse.AvatarSelectorController");

test("avatarTemplate", function() {
  var avatarSelectorController = testController(Discourse.AvatarSelectorController);
  avatarSelectorController.setProperties(avatarSelector);

  equal(avatarSelectorController.get("avatarTemplate"),
        avatarSelector.get("gravatar_template"),
        "we are using gravatar by default");

  avatarSelectorController.send('useUploadedAvatar');

  equal(avatarSelectorController.get("avatarTemplate"),
        avatarSelector.get("uploaded_avatar_template"),
        "calling useUploadedAvatar switches to using the uploaded avatar");

  avatarSelectorController.send('useGravatar');

  equal(avatarSelectorController.get("avatarTemplate"),
        avatarSelector.get("gravatar_template"),
       "calling useGravatar switches to using gravatar");
});
