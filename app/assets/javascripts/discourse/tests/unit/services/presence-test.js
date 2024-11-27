import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { setTestPresence } from "discourse/lib/user-presence";
import { PresenceChannelNotFound } from "discourse/services/presence";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  currentUser,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";

function usersFixture() {
  return [
    {
      id: 1,
      username: "bruce0",
      name: "Bruce Wayne",
      avatar_template: "/letter_avatar_proxy/v4/letter/b/90ced4/{size}.png",
    },
    {
      id: 2,
      username: "bruce1",
      name: "Bruce Wayne",
      avatar_template: "/letter_avatar_proxy/v4/letter/b/9de053/{size}.png",
    },
    {
      id: 3,
      username: "bruce2",
      name: "Bruce Wayne",
      avatar_template: "/letter_avatar_proxy/v4/letter/b/35a633/{size}.png",
    },
  ];
}

module("Unit | Service | presence | subscribing", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/presence/get", (request) => {
      const result = {};

      request.queryParams.channels.forEach((c) => {
        if (c.startsWith("/test/")) {
          result[c] = {
            count: 3,
            last_message_id: 1,
            users: usersFixture(),
          };
        } else if (c.startsWith("/count-only/")) {
          result[c] = {
            count: 3,
            last_message_id: 1,
          };
        } else {
          result[c] = null;
        }
      });

      return response(result);
    });
  });

  test("subscribing and receiving updates", async function (assert) {
    let presenceService = getOwner(this).lookup("service:presence");
    let channel = presenceService.getChannel("/test/ch1");
    let changes = 0;
    const countChanges = () => changes++;
    channel.on("change", countChanges);

    assert.strictEqual(channel.name, "/test/ch1");

    await channel.subscribe({
      users: usersFixture(),
      last_message_id: 1,
    });
    assert.strictEqual(changes, 1);

    assert.strictEqual(channel.users.length, 3, "it starts with three users");

    await publishToMessageBus(
      "/presence/test/ch1",
      {
        leaving_user_ids: [1],
      },
      0,
      2
    );

    assert.strictEqual(channel.users.length, 2, "one user is removed");
    assert.strictEqual(changes, 2);

    await publishToMessageBus(
      "/presence/test/ch1",
      {
        entering_users: [usersFixture()[0]],
      },
      0,
      3
    );

    assert.strictEqual(channel.users.length, 3, "one user is added");
    assert.strictEqual(changes, 3);
    channel.off("change", countChanges);
  });

  test("fetches data when no initial state", async function (assert) {
    let presenceService = getOwner(this).lookup("service:presence");
    let channel = presenceService.getChannel("/test/ch1");

    await channel.subscribe();

    assert.strictEqual(channel.users.length, 3, "loads initial state");

    await publishToMessageBus(
      "/presence/test/ch1",
      {
        leaving_user_ids: [1],
      },
      0,
      2
    );

    assert.strictEqual(
      channel.users.length,
      2,
      "updates following messagebus message"
    );

    const stub = sinon
      .stub(console, "log")
      .withArgs(
        "PresenceChannel '/test/ch1' dropped message (received 99, expecting 3), resyncing..."
      );

    await publishToMessageBus(
      "/presence/test/ch1",
      {
        leaving_user_ids: [2],
      },
      0,
      99
    );

    sinon.assert.calledOnce(stub);
    assert.strictEqual(
      channel.users.length,
      3,
      "detects missed messagebus message, fetches data from server"
    );
  });

  test("raises error when subscribing to nonexistent channel", async function (assert) {
    let presenceService = getOwner(this).lookup("service:presence");
    let channel = presenceService.getChannel("/nonexistent/ch1");

    assert.rejects(
      channel.subscribe(),
      PresenceChannelNotFound,
      "raises not found"
    );
  });

  test("can subscribe to count_only channel", async function (assert) {
    let presenceService = getOwner(this).lookup("service:presence");
    let channel = presenceService.getChannel("/count-only/ch1");

    await channel.subscribe();

    assert.strictEqual(channel.count, 3, "has the correct count");
    assert.true(channel.countOnly, "identifies as countOnly");
    assert.strictEqual(channel.users, null, "has null users list");

    await publishToMessageBus(
      "/presence/count-only/ch1",
      {
        count_delta: 1,
      },
      0,
      2
    );

    assert.strictEqual(channel.count, 4, "updates the count via messagebus");

    await publishToMessageBus(
      "/presence/count-only/ch1",
      {
        leaving_user_ids: [2],
      },
      0,
      3
    );

    assert.strictEqual(
      channel.count,
      3,
      "resubscribes when receiving a non-count-only message"
    );
  });

  test("can share data between multiple PresenceChannel objects", async function (assert) {
    let presenceService = getOwner(this).lookup("service:presence");
    let channel = presenceService.getChannel("/test/ch1");
    let channelDup = presenceService.getChannel("/test/ch1");

    await channel.subscribe();
    assert.true(channel.subscribed, "channel is subscribed");
    assert.strictEqual(channel.count, 3, "channel has the correct count");
    assert.strictEqual(channel.users.length, 3, "channel has users");

    assert.false(channelDup.subscribed, "channelDup is not subscribed");
    assert.strictEqual(channelDup.count, undefined, "channelDup has no count");
    assert.strictEqual(channelDup.users, undefined, "channelDup has users");

    await channelDup.subscribe();
    assert.true(channelDup.subscribed, "channelDup can subscribe");
    assert.true(
      !!channelDup._presenceState,
      "channelDup has a valid internal state"
    );
    assert.strictEqual(
      channelDup._presenceState,
      channel._presenceState,
      "internal state is shared"
    );

    await channel.unsubscribe();
    assert.false(channel.subscribed, "channel can unsubscribe");
    assert.strictEqual(
      channelDup._presenceState,
      presenceService._presenceChannelStates.get(channel.name),
      "state is maintained in the subscribed channel"
    );

    await channelDup.unsubscribe();
    assert.false(channel.subscribed, "channelDup can unsubscribe");
    assert.strictEqual(
      presenceService._presenceChannelStates.get(channel.name),
      undefined,
      "state is cleared"
    );
  });
});

module("Unit | Service | presence | entering and leaving", function (hooks) {
  setupTest(hooks);

  let responseStartPromise;
  let resolveResponseStartPromise;
  let responseWaitPromise;

  const requests = [];

  hooks.beforeEach(function () {
    responseStartPromise = new Promise(
      (resolve) => (resolveResponseStartPromise = resolve)
    );

    pretender.post("/presence/update", async (request) => {
      resolveResponseStartPromise();
      await responseWaitPromise;

      const body = new URLSearchParams(request.requestBody);
      requests.push(body);

      const result = {};
      const channelsRequested = body.getAll("present_channels[]");
      channelsRequested.forEach((c) => {
        result[c] = c.startsWith("/test/");
      });

      return response(result);
    });
  });

  hooks.afterEach(function () {
    requests.clear();
    responseWaitPromise = null;
    responseStartPromise = null;
  });

  test("can join and leave channels", async function (assert) {
    const presenceService = getOwner(this).lookup("service:presence");
    presenceService.currentUser = currentUser();
    const channel = presenceService.getChannel("/test/ch1");

    await channel.enter();
    assert.strictEqual(requests.length, 1, "updated the server for enter");
    let presentChannels = requests.pop().getAll("present_channels[]");
    assert.deepEqual(
      presentChannels,
      ["/test/ch1"],
      "included the correct present channel"
    );

    await channel.leave();
    assert.strictEqual(requests.length, 1, "updated the server for leave");
    const request = requests.pop();
    presentChannels = request.getAll("present_channels[]");
    const leaveChannels = request.getAll("leave_channels[]");
    assert.deepEqual(presentChannels, [], "included no present channels");
    assert.deepEqual(
      leaveChannels,
      ["/test/ch1"],
      "included the correct leave channel"
    );
  });

  test("join should be a no-op if already present", async function (assert) {
    const presenceService = getOwner(this).lookup("service:presence");
    presenceService.currentUser = currentUser();
    const channel = presenceService.getChannel("/test/ch1");

    await channel.enter();
    assert.strictEqual(requests.length, 1, "updated the server for enter");

    await channel.enter();
    assert.strictEqual(
      requests.length,
      1,
      "does not update the server unnecessarily"
    );
  });

  test("leave should be a no-op if not present", async function (assert) {
    const presenceService = getOwner(this).lookup("service:presence");
    presenceService.currentUser = currentUser();
    const channel = presenceService.getChannel("/test/ch1");

    await channel.enter();
    assert.strictEqual(requests.length, 1, "updated the server for enter");

    await channel.leave();
    assert.strictEqual(requests.length, 2, "updated the server for leave");

    await channel.leave();
    assert.strictEqual(
      requests.length,
      2,
      "did not update the server unnecessarily"
    );
  });

  test("interleaved join/leave calls work correctly", async function (assert) {
    let resolveServerResponse;
    responseWaitPromise = new Promise(
      (resolve) => (resolveServerResponse = resolve)
    );

    const presenceService = getOwner(this).lookup("service:presence");
    presenceService.currentUser = currentUser();
    const channel = presenceService.getChannel("/test/ch1");

    const enterPromise = channel.enter();

    await responseStartPromise;

    const leavePromise = channel.leave();

    resolveServerResponse();

    await enterPromise;
    await leavePromise;

    assert.strictEqual(requests.length, 2, "server received two requests");

    const presentChannels = requests.map((r) => r.getAll("present_channels[]"));
    const leaveChannels = requests.map((r) => r.getAll("leave_channels[]"));

    assert.deepEqual(presentChannels, [["/test/ch1"], []]);
    assert.deepEqual(leaveChannels, [[], ["/test/ch1"]]);
  });

  test("raises an error when entering a non-existent channel", async function (assert) {
    const presenceService = getOwner(this).lookup("service:presence");
    presenceService.currentUser = currentUser();
    const channel = presenceService.getChannel("/blah/does-not-exist");
    await assert.rejects(
      channel.enter(),
      PresenceChannelNotFound,
      "raises a not found error"
    );
  });

  test("deduplicates calls from multiple PresenceChannel instances", async function (assert) {
    const presenceService = getOwner(this).lookup("service:presence");
    presenceService.currentUser = currentUser();
    const channel = presenceService.getChannel("/test/ch1");
    const channelDup = presenceService.getChannel("/test/ch1");

    await channel.enter();
    assert.true(channel.present, "channel is present");
    assert.false(channelDup.present, "channelDup is absent");
    assert.true(
      presenceService._presentChannels.has("/test/ch1"),
      "service shows present"
    );

    await channelDup.enter();
    assert.true(channel.present, "channel is present");
    assert.true(channelDup.present, "channelDup is present");
    assert.true(
      presenceService._presentChannels.has("/test/ch1"),
      "service shows present"
    );

    await channel.leave();
    assert.false(channel.present, "channel is absent");
    assert.true(channelDup.present, "channelDup is present");
    assert.true(
      presenceService._presentChannels.has("/test/ch1"),
      "service shows present"
    );

    await channelDup.leave();
    assert.false(channel.present, "channel is absent");
    assert.false(channel.present, "channelDup is absent");
    assert.false(
      presenceService._presentChannels.has("/test/ch1"),
      "service shows absent"
    );
  });

  test("updates the server presence after going idle", async function (assert) {
    const presenceService = getOwner(this).lookup("service:presence");
    presenceService.currentUser = currentUser();
    const channel = presenceService.getChannel("/test/ch1");

    await channel.enter();
    requests.pop(); // Throw away this request

    setTestPresence(false);

    await presenceService._updateServer();
    assert.strictEqual(
      requests.length,
      1,
      "updated the server after going idle"
    );
    let request = requests.pop();
    assert.true(
      request.getAll("leave_channels[]").includes("/test/ch1"),
      "left ch1"
    );

    // Go back online
    setTestPresence(true);
    await presenceService._updateServer();
    assert.strictEqual(
      requests.length,
      1,
      "updated the server after going back online"
    );
    request = requests.pop();
    assert.true(
      request.getAll("present_channels[]").includes("/test/ch1"),
      "rejoined ch1"
    );
  });

  test("handles the onlyWhileActive flag", async function (assert) {
    const presenceService = getOwner(this).lookup("service:presence");
    presenceService.currentUser = currentUser();
    const channel = presenceService.getChannel("/test/ch1");
    await channel.enter();
    requests.pop(); // Throw away this request

    const channel2 = presenceService.getChannel("/test/ch2");
    await channel2.enter({ onlyWhileActive: false });

    assert.strictEqual(requests.length, 1, "updated the server");
    let presentChannels = requests.pop().getAll("present_channels[]");
    assert.deepEqual(
      presentChannels,
      ["/test/ch1", "/test/ch2"],
      "included both channels when active"
    );

    setTestPresence(false);
    await presenceService._updateServer();
    assert.strictEqual(
      requests.length,
      1,
      "updated the server after going idle"
    );
    let request = requests.pop();
    assert.deepEqual(
      request.getAll("present_channels[]"),
      ["/test/ch2"],
      "ch2 remained present"
    );
    assert.true(
      request.getAll("leave_channels[]").includes("/test/ch1"),
      "left ch1"
    );

    await channel2.leave();
    assert.strictEqual(requests.length, 1, "updated the server");
    request = requests.pop();
    assert.true(
      request.getAll("leave_channels[]").includes("/test/ch2"),
      "left ch2"
    );

    await presenceService._updateServer();
    assert.strictEqual(
      requests.length,
      0,
      "skips sending empty updates to the server"
    );
  });

  test("don't spam requests when server returns 429", async function (assert) {
    let requestCount = 0;
    pretender.post("/presence/update", () => {
      requestCount++;
      if (requestCount === 1) {
        return response(429, { extras: { wait_seconds: 2 } });
      } else {
        return response({});
      }
    });

    const presenceService = getOwner(this).lookup("service:presence");
    presenceService.currentUser = currentUser();
    const channel = presenceService.getChannel("/test/ch1");

    setTimeout(() => {
      assert.strictEqual(requestCount, 1);
      assert.step("request");
    }, 500);

    await channel.enter();
    assert.verifySteps(["request"]);
  });
});
