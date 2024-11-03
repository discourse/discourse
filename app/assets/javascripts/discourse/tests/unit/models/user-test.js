import { getOwner } from "@ember/owner";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import PreloadStore from "discourse/lib/preload-store";
import User from "discourse/models/user";

module("Unit | Model | user", function (hooks) {
  setupTest(hooks);

  test("staff", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const user = store.createRecord("user", { id: 1, username: "eviltrout" });

    assert.ok(!user.staff, "user is not staff");

    user.toggleProperty("moderator");
    assert.ok(user.staff, "moderators are staff");

    user.setProperties({ moderator: false, admin: true });
    assert.ok(user.staff, "admins are staff");
  });

  test("searchContext", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const user = store.createRecord("user", { id: 1, username: "EvilTrout" });

    assert.deepEqual(
      user.searchContext,
      { type: "user", id: "eviltrout", user },
      "has a search context"
    );
  });

  test("isAllowedToUploadAFile", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const user = store.createRecord("user", { trust_level: 0, admin: true });
    assert.ok(
      user.isAllowedToUploadAFile("image"),
      "admin can always upload a file"
    );

    user.setProperties({ admin: false, moderator: true });
    assert.ok(
      user.isAllowedToUploadAFile("image"),
      "moderator can always upload a file"
    );
  });

  test("canMangeGroup", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const user = store.createRecord("user", { admin: true });
    const group = store.createRecord("group", { automatic: true });

    assert.strictEqual(
      user.canManageGroup(group),
      false,
      "automatic groups cannot be managed."
    );

    group.set("automatic", false);
    group.setProperties({ can_admin_group: true });

    assert.strictEqual(
      user.canManageGroup(group),
      true,
      "an admin should be able to manage the group"
    );

    user.set("admin", false);
    group.setProperties({ is_group_owner: true });

    assert.strictEqual(
      user.canManageGroup(group),
      true,
      "a group owner should be able to manage the group"
    );
  });

  test("muted ids", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const user = store.createRecord("user", {
      username: "chuck",
      muted_category_ids: [],
    });

    assert.deepEqual(user.calculateMutedIds(0, 1, "muted_category_ids"), [1]);
    assert.deepEqual(user.calculateMutedIds(1, 1, "muted_category_ids"), []);
  });

  test("createCurrent() guesses timezone if user doesn't have it set", async function (assert) {
    PreloadStore.store("currentUser", {
      username: "eviltrout",
      user_option: { timezone: null },
    });
    const expectedTimezone = "Africa/Casablanca";
    sinon.stub(moment.tz, "guess").returns(expectedTimezone);

    const currentUser = User.createCurrent();

    assert.deepEqual(currentUser.user_option.timezone, expectedTimezone);

    await settled(); // `User` sends a request to save the timezone
  });

  test("createCurrent() doesn't guess timezone if user has it already set", function (assert) {
    const timezone = "Africa/Casablanca";
    PreloadStore.store("currentUser", {
      username: "eviltrout",
      user_option: { timezone },
    });
    const spyMomentGuess = sinon.spy(moment.tz, "guess");

    User.createCurrent();

    assert.ok(spyMomentGuess.notCalled);
  });

  test("subsequent calls to trackStatus and stopTrackingStatus increase and decrease subscribers counter", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const user = store.createRecord("user");
    assert.strictEqual(user.statusManager._subscribersCount, 0);

    user.statusManager.trackStatus();
    assert.strictEqual(user.statusManager._subscribersCount, 1);

    user.statusManager.trackStatus();
    assert.strictEqual(user.statusManager._subscribersCount, 2);

    user.statusManager.stopTrackingStatus();
    assert.strictEqual(user.statusManager._subscribersCount, 1);

    user.statusManager.stopTrackingStatus();
    assert.strictEqual(user.statusManager._subscribersCount, 0);
  });

  test("attempt to stop tracking status if status wasn't tracked doesn't throw", function (assert) {
    assert.expect(0);
    const store = getOwner(this).lookup("service:store");
    const user = store.createRecord("user");
    user.statusManager.stopTrackingStatus();
  });

  test("clears statuses of several users correctly when receiving status updates via appEvents", function (assert) {
    const status1 = {
      description: "user1 status",
      emoji: "mega",
    };
    const status2 = {
      description: "user2 status",
      emoji: "speech_balloon",
    };
    const store = getOwner(this).lookup("service:store");
    const user1 = store.createRecord("user", {
      id: 1,
      status: status1,
    });
    const user2 = store.createRecord("user", { id: 2, status: status2 });
    const appEvents = user1.appEvents;

    try {
      user1.statusManager.trackStatus();
      user2.statusManager.trackStatus();
      assert.strictEqual(user1.status, status1);
      assert.strictEqual(user2.status, status2);

      appEvents.trigger("user-status:changed", { [user1.id]: null });
      assert.strictEqual(user1.status, null);
      assert.strictEqual(user2.status, status2);

      appEvents.trigger("user-status:changed", { [user2.id]: null });
      assert.strictEqual(user1.status, null);
      assert.strictEqual(user2.status, null);
    } finally {
      user1.statusManager.stopTrackingStatus();
      user2.statusManager.stopTrackingStatus();
    }
  });

  test("create() doesn't set internal status tracking fields", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const user = store.createRecord("user", {
      _subscribersCount: 10,
      _clearStatusTimerId: 100,
    });

    assert.notOk(
      user.hasOwnProperty("_subscribersCount"),
      "_subscribersCount wasn't set"
    );
    assert.notOk(
      user.hasOwnProperty("_clearStatusTimerId"),
      "_clearStatusTimerId wasn't set"
    );
  });

  test("pmPath", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const user = store.createRecord("user", {
      id: 1,
      username: "eviltrout",
      groups: [],
    });
    const topic = store.createRecord("topic", { id: 1, details: {} });

    assert.strictEqual(
      user.pmPath(topic),
      `/u/${user.username_lower}/messages`,
      "user is in no groups and not directly allowed on the topic"
    );

    const group1 = store.createRecord("group", { id: 1, name: "group1" });
    const group2 = store.createRecord("group", { id: 2, name: "group2" });
    topic.details = {
      allowed_users: [user],
      allowed_groups: [group1, group2],
    };
    user.groups = [group2];

    assert.strictEqual(
      user.pmPath(topic),
      `/u/${user.username_lower}/messages`,
      "user is in one group (not the first one) and allowed on the topic"
    );

    topic.details.allowed_users = [];

    assert.strictEqual(
      user.pmPath(topic),
      `/u/${user.username_lower}/messages/group/${group2.name}`,
      "user is in one group (not the first one) and not allowed on the topic"
    );
  });
});
