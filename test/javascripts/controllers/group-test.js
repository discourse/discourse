moduleFor("controller:group", {
  needs: ["controller:application"]
});

QUnit.test("canEditGroup", function(assert) {
  const GroupController = this.subject();

  GroupController.setProperties({
    model: { is_group_owner: true, automatic: true }
  });

  assert.equal(
    GroupController.get("canEditGroup"),
    false,
    "automatic groups cannot be edited"
  );

  GroupController.set("model.automatic", false);

  assert.equal(
    GroupController.get("canEditGroup"),
    true,
    "owners can edit groups"
  );

  GroupController.set("model.is_group_owner", false);

  assert.equal(
    GroupController.get("canEditGroup"),
    false,
    "normal users cannot edit groups"
  );
});
