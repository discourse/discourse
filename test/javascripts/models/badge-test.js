import Badge from "discourse/models/badge";

QUnit.module("model:badge");

QUnit.test("newBadge", assert => {
  const badge1 = Badge.create({ name: "New Badge" }),
    badge2 = Badge.create({ id: 1, name: "Old Badge" });
  assert.ok(badge1.get("newBadge"), "badges without ids are new");
  assert.ok(!badge2.get("newBadge"), "badges with ids are not new");
});

QUnit.test("createFromJson array", assert => {
  const badgesJson = {
    badge_types: [{ id: 6, name: "Silver 1" }],
    badges: [{ id: 1126, name: "Badge 1", description: null, badge_type_id: 6 }]
  };

  const badges = Badge.createFromJson(badgesJson);

  assert.ok(Array.isArray(badges), "returns an array");
  assert.equal(badges[0].get("name"), "Badge 1", "badge details are set");
  assert.equal(
    badges[0].get("badge_type.name"),
    "Silver 1",
    "badge_type reference is set"
  );
});

QUnit.test("createFromJson single", assert => {
  const badgeJson = {
    badge_types: [{ id: 6, name: "Silver 1" }],
    badge: { id: 1126, name: "Badge 1", description: null, badge_type_id: 6 }
  };

  const badge = Badge.createFromJson(badgeJson);

  assert.ok(!Array.isArray(badge), "does not returns an array");
});

QUnit.test("updateFromJson", assert => {
  const badgeJson = {
    badge_types: [{ id: 6, name: "Silver 1" }],
    badge: { id: 1126, name: "Badge 1", description: null, badge_type_id: 6 }
  };
  const badge = Badge.create({ name: "Badge 1" });
  badge.updateFromJson(badgeJson);
  assert.equal(badge.get("id"), 1126, "id is set");
  assert.equal(
    badge.get("badge_type.name"),
    "Silver 1",
    "badge_type reference is set"
  );
});

QUnit.test("save", assert => {
  assert.expect(0);
  const badge = Badge.create({
    name: "New Badge",
    description: "This is a new badge.",
    badge_type_id: 1
  });
  return badge.save(["name", "description", "badge_type_id"]);
});

QUnit.test("destroy", assert => {
  assert.expect(0);
  const badge = Badge.create({
    name: "New Badge",
    description: "This is a new badge.",
    badge_type_id: 1
  });
  badge.destroy();
  badge.set("id", 3);
  return badge.destroy();
});
