import Group from "discourse/models/group";

QUnit.module("model:group");

QUnit.test("displayName", assert => {
  const group = Group.create({ name: "test", display_name: "donkey" });

  assert.equal(
    group.displayName,
    "donkey",
    "it should return the display name"
  );

  group.set("display_name", null);

  assert.equal(
    group.displayName,
    "test",
    "it should return the group's name"
  );
});
