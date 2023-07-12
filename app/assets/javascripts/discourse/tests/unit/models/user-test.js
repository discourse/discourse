import { module, test } from "qunit";
import { setupTest } from "ember-qunit";
import PreloadStore from "discourse/lib/preload-store";
import sinon from "sinon";
import { settled } from "@ember/test-helpers";
import User from "discourse/models/user";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { getOwner } from "discourse-common/lib/get-owner";
import * as userTips from "discourse/lib/user-tips";

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
    assert.strictEqual(user._subscribersCount, 0);

    user.trackStatus();
    assert.strictEqual(user._subscribersCount, 1);

    user.trackStatus();
    assert.strictEqual(user._subscribersCount, 2);

    user.stopTrackingStatus();
    assert.strictEqual(user._subscribersCount, 1);

    user.stopTrackingStatus();
    assert.strictEqual(user._subscribersCount, 0);
  });

  test("attempt to stop tracking status if status wasn't tracked doesn't throw", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const user = store.createRecord("user");
    user.stopTrackingStatus();
    assert.ok(true);
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
      user1.trackStatus();
      user2.trackStatus();
      assert.strictEqual(user1.status, status1);
      assert.strictEqual(user2.status, status2);

      appEvents.trigger("user-status:changed", { [user1.id]: null });
      assert.strictEqual(user1.status, null);
      assert.strictEqual(user2.status, status2);

      appEvents.trigger("user-status:changed", { [user2.id]: null });
      assert.strictEqual(user1.status, null);
      assert.strictEqual(user2.status, null);
    } finally {
      user1.stopTrackingStatus();
      user2.stopTrackingStatus();
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

  test("hideUserTipForever() makes a single request", async function (assert) {
    const site = getOwner(this).lookup("service:site");
    site.set("user_tips", { first_notification: 1 });
    const store = getOwner(this).lookup("service:store");
    const user = store.createRecord("user", { username: "eviltrout" });

    let requestsCount = 0;
    pretender.put("/u/eviltrout.json", () => {
      requestsCount += 1;
      return response(200, {
        user: {
          user_option: {
            seen_popups: [1],
          },
        },
      });
    });

    await user.hideUserTipForever("first_notification");
    assert.strictEqual(requestsCount, 1);

    await user.hideUserTipForever("first_notification");
    assert.strictEqual(requestsCount, 1);
  });

  test("hideUserTipForever() can hide the user tip", async function (assert) {
    const site = getOwner(this).lookup("service:site");
    site.set("user_tips", { first_notification: 1 });
    const store = getOwner(this).lookup("service:store");
    const user = store.createRecord("user", { username: "eviltrout" });

    const hideSpy = sinon.spy(userTips, "hideUserTip");
    const showNextSpy = sinon.spy(userTips, "showNextUserTip");
    await user.hideUserTipForever("first_notification");

    assert.ok(hideSpy.calledWith("first_notification"));
    assert.ok(showNextSpy.calledWith());
  });
});
