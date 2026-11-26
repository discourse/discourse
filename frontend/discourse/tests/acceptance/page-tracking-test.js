import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

function setupPretender(server, helper) {
  server.post("/srv/pv", () => helper.response({}));
}

function setupTrackingSessionId(needs) {
  let meta;

  needs.hooks.beforeEach(function () {
    meta = document.createElement("meta");
    meta.name = "discourse-track-view-session-id";
    meta.content = "tracking-session-id";
    document.head.appendChild(meta);

    this.owner.lookup("service:human-activity-tracker").scheduleFlush = () =>
      null;
  });

  needs.hooks.afterEach(function () {
    meta.remove();
  });
}

function assertBeacon(assert, { navigation }, message) {
  const beacons = pretender.handledRequests.filter(
    (request) => request.url === "/srv/pv"
  );
  assert.strictEqual(beacons.length, 1, message);
  assert.strictEqual(
    JSON.parse(beacons[0].requestBody).navigation,
    navigation,
    `${message} with the expected navigation flag`
  );

  pretender.handledRequests = [];
}

async function navigateAndAssertBeacons(assert) {
  await visit("/");
  assertBeacon(
    assert,
    { navigation: undefined },
    "sends a beacon for the initial page load"
  );

  await click("#site-logo");
  assertBeacon(
    assert,
    { navigation: true },
    "sends a beacon for reloading latest"
  );

  await visit("/t/-/280");
  assertBeacon(
    assert,
    { navigation: true },
    "sends a beacon for navigating to a topic"
  );
}

acceptance("Page tracking - loading slider", function (needs) {
  needs.user();
  needs.pretender(setupPretender);
  setupTrackingSessionId(needs);

  test("sends one beacon per navigation", async function (assert) {
    await navigateAndAssertBeacons(assert);
  });
});

acceptance("Page tracking - loading spinner", function (needs) {
  needs.user();
  needs.pretender(setupPretender);
  setupTrackingSessionId(needs);
  needs.settings({
    page_loading_indicator: "spinner",
  });

  test("sends one beacon per navigation", async function (assert) {
    await navigateAndAssertBeacons(assert);
  });
});

acceptance("Page tracking - without a session ID", function (needs) {
  needs.user();
  needs.pretender(setupPretender);

  test("does not send beacon requests", async function (assert) {
    await visit("/");

    const beaconRequests = pretender.handledRequests.filter(
      (request) => request.url === "/srv/pv"
    );
    assert.strictEqual(
      beaconRequests.length,
      0,
      "page tracking skips the beacon request"
    );
  });
});
