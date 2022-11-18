import { module, test } from "qunit";
import Badge from "discourse/models/badge";
import { setupTest } from "ember-qunit";
import { getOwner } from "discourse-common/lib/get-owner";

module("Unit | Model | badge", function (hooks) {
  setupTest(hooks);

  test("newBadge", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const badge1 = store.createRecord("badge", { name: "New Badge" });
    const badge2 = store.createRecord("badge", { id: 1, name: "Old Badge" });

    assert.ok(badge1.newBadge, "badges without ids are new");
    assert.ok(!badge2.newBadge, "badges with ids are not new");
  });

  test("createFromJson array", function (assert) {
    const badgesJson = {
      badge_types: [{ id: 6, name: "Silver 1" }],
      badges: [
        { id: 1126, name: "Badge 1", description: null, badge_type_id: 6 },
      ],
    };

    const badges = Badge.createFromJson(badgesJson);

    assert.ok(Array.isArray(badges), "returns an array");
    assert.strictEqual(badges[0].name, "Badge 1", "badge details are set");
    assert.strictEqual(
      badges[0].badge_type.name,
      "Silver 1",
      "badge_type reference is set"
    );
  });

  test("createFromJson single", function (assert) {
    const badgeJson = {
      badge_types: [{ id: 6, name: "Silver 1" }],
      badge: { id: 1126, name: "Badge 1", description: null, badge_type_id: 6 },
    };

    const badge = Badge.createFromJson(badgeJson);

    assert.ok(!Array.isArray(badge), "does not returns an array");
  });

  test("updateFromJson", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const badge = store.createRecord("badge", { name: "Badge 1" });
    badge.updateFromJson({
      badge_types: [{ id: 6, name: "Silver 1" }],
      badge: { id: 1126, name: "Badge 1", description: null, badge_type_id: 6 },
    });

    assert.strictEqual(badge.id, 1126, "id is set");
    assert.strictEqual(
      badge.badge_type.name,
      "Silver 1",
      "badge_type reference is set"
    );
  });

  test("save", function (assert) {
    assert.expect(0);
    const store = getOwner(this).lookup("service:store");
    const badge = store.createRecord("badge", {
      name: "New Badge",
      description: "This is a new badge.",
      badge_type_id: 1,
    });
    badge.save(["name", "description", "badge_type_id"]);
  });

  test("destroy", function (assert) {
    assert.expect(0);
    const store = getOwner(this).lookup("service:store");
    const badge = store.createRecord("badge", {
      name: "New Badge",
      description: "This is a new badge.",
      badge_type_id: 1,
    });
    badge.destroy();
    badge.set("id", 3);
    badge.destroy();
  });
});
