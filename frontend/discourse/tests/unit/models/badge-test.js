import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import Badge from "discourse/models/badge";
import UserBadge from "discourse/models/user-badge";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";

module("Unit | Model | badge", function (hooks) {
  setupTest(hooks);

  test("newBadge", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const badge1 = store.createRecord("badge", { name: "New Badge" });
    const badge2 = store.createRecord("badge", { id: 1, name: "Old Badge" });

    assert.true(badge1.newBadge, "badges without ids are new");
    assert.false(badge2.newBadge, "badges with ids are not new");
  });

  test("createFromJson array", function (assert) {
    const badgesJson = {
      badge_types: [{ id: 6, name: "Silver 1" }],
      badges: [
        { id: 1126, name: "Badge 1", description: null, badge_type_id: 6 },
      ],
    };

    const badges = Badge.createFromJson(badgesJson);

    assert.true(Array.isArray(badges), "returns an array");
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

    assert.false(Array.isArray(badge), "does not returns an array");
  });

  test("has_badge is kept when the payload provides it", function (assert) {
    const badges = Badge.createFromJson({
      badge_types: [{ id: 6, name: "Silver 1" }],
      badges: [
        {
          id: 1127,
          name: "Badge 1",
          description: null,
          badge_type_id: 6,
          has_badge: true,
        },
        {
          id: 1128,
          name: "Badge 2",
          description: null,
          badge_type_id: 6,
          has_badge: false,
        },
      ],
    });

    assert.true(badges[0].has_badge, "true is preserved");
    assert.false(badges[1].has_badge, "false is preserved");
  });

  test("has_badge is cleared by a payload that omits it", function (assert) {
    Badge.createFromJson({
      badge_types: [{ id: 6, name: "Silver 1" }],
      badges: [
        {
          id: 1126,
          name: "Badge 1",
          description: null,
          badge_type_id: 6,
          has_badge: true,
        },
      ],
    });

    const sideloaded = Badge.createFromJson({
      badge_types: [{ id: 6, name: "Silver 1" }],
      badges: [
        { id: 1126, name: "Badge 1", description: null, badge_type_id: 6 },
      ],
    });

    assert.false(
      sideloaded[0].has_badge,
      "a payload that cannot know about the viewer's grants clears the flag"
    );
  });

  test("has_badge survives a badge sideloaded with user badges", function (assert) {
    Badge.createFromJson({
      badge_types: [{ id: 6, name: "Silver 1" }],
      badges: [
        {
          id: 1129,
          name: "Badge 1",
          description: null,
          badge_type_id: 6,
          has_badge: true,
        },
      ],
    });

    const userBadges = UserBadge.createFromJson({
      badge_types: [{ id: 6, name: "Silver 1" }],
      badges: [
        { id: 1129, name: "Badge 1", description: null, badge_type_id: 6 },
      ],
      user_badges: [{ id: 42, badge_id: 1129, granted_at: "2020-01-01" }],
    });

    assert.true(
      userBadges[0].badge.has_badge,
      "a payload that cannot know the viewer's grants leaves the flag alone"
    );
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

  test("save", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const badge = store.createRecord("badge", {
      id: 1999,
      name: "New Badge",
      description: "This is a new badge.",
      badge_type_id: 1,
    });

    pretender.put("/admin/badges/1999", (request) => {
      const params = parsePostData(request.requestBody);
      assert.deepEqual(params, { description: "A special badge!" });
      assert.step("called API");
      return response({});
    });

    await badge.save({
      description: "A special badge!",
    });

    assert.verifySteps(["called API"]);
  });

  test("destroy", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const badge = store.createRecord("badge", {
      name: "New Badge",
      description: "This is a new badge.",
      badge_type_id: 1,
    });

    pretender.delete("/admin/badges/3", () => {
      assert.step("called API");
      return response({});
    });

    // Doesn't call the API if destroying a new badge
    await badge.destroy();

    badge.set("id", 3);
    await badge.destroy();

    assert.verifySteps(["called API"]);
  });
});
