moduleFor("controller:group");

test("canEditGroup", function() {
  const GroupController = this.subject();

  GroupController.setProperties({
    model: { is_group_owner: true, automatic: true }
  });

  equal(GroupController.get("canEditGroup"), false, "automatic groups cannot be edited");

  GroupController.set("model.automatic", false);

  equal(GroupController.get("canEditGroup"), true, "owners can edit groups");

  GroupController.set("model.is_group_owner", false);

  equal(GroupController.get("canEditGroup"), false, "normal users cannot edit groups");
});
