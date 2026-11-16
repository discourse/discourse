import { getOwner } from "@ember/owner";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { ajax } from "discourse/lib/ajax";
import pretender from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const trackViewHeaderName = "Discourse-Track-View";

function setupPretender(server, helper) {
  server.post("/srv/pv", () => helper.response({}));

  server.get("/fake-analytics-endpoint", (request) => {
    if (request.requestHeaders[trackViewHeaderName]) {
      throw "Fake analytics endpoint was called with track-view header";
    }
    return helper.response({});
  });
}

function setupFakeAnalytics(ref) {
  getOwner(ref)
    .lookup("service:router")
    .on("routeDidChange", () => ajax("/fake-analytics-endpoint"));
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

function assertRequests({ assert, tracked, untracked, beacons, message }) {
  let trackedCount = 0,
    untrackedCount = 0,
    beaconCount = 0;

  const requests = pretender.handledRequests;
  requests.forEach((request) => {
    if (request.url === "/srv/pv") {
      beaconCount++;
    } else if (request.requestHeaders[trackViewHeaderName]) {
      trackedCount++;
    } else {
      untrackedCount++;
    }
  });

  assert.strictEqual(trackedCount, tracked, `${message} (tracked)`);
  assert.strictEqual(untrackedCount, untracked, `${message} (untracked)`);
  assert.strictEqual(beaconCount, beacons, `${message} (beacons)`);

  pretender.handledRequests = [];
}

acceptance("Page tracking - loading slider", function (needs) {
  needs.user();
  needs.pretender(setupPretender);
  setupTrackingSessionId(needs);

  test("sets the Discourse-Track-View header on the navigation request", async function (assert) {
    setupFakeAnalytics(this);

    assertRequests({
      assert,
      tracked: 0,
      untracked: 1,
      beacons: 0,
      message: "no tracked requests before app boot",
    });

    await visit("/");
    assertRequests({
      assert,
      tracked: 0,
      untracked: 2,
      beacons: 1,
      message: "no ajax tracked for initial page load",
    });

    await click("#site-logo");
    assertRequests({
      assert,
      tracked: 1,
      untracked: 1,
      beacons: 1,
      message: "tracked one pageview for reloading latest",
    });

    await visit("/t/-/280");
    assertRequests({
      assert,
      tracked: 1,
      untracked: 1,
      beacons: 1,
      message: "tracked one pageview for navigating to topic",
    });
  });
});

acceptance("Page tracking - loading spinner", function (needs) {
  needs.user();
  needs.pretender(setupPretender);
  setupTrackingSessionId(needs);
  needs.settings({
    page_loading_indicator: "spinner",
  });

  test("sets the Discourse-Track-View header on the navigation request", async function (assert) {
    setupFakeAnalytics(this);

    assertRequests({
      assert,
      tracked: 0,
      untracked: 1,
      beacons: 0,
      message: "no tracked requests before app boot",
    });

    await visit("/");
    assertRequests({
      assert,
      tracked: 0,
      untracked: 2,
      beacons: 1,
      message: "no ajax tracked for initial page load",
    });

    await click("#site-logo");
    assertRequests({
      assert,
      tracked: 1,
      untracked: 1,
      beacons: 1,
      message: "tracked one pageview for reloading latest",
    });

    await visit("/t/-/280");
    assertRequests({
      assert,
      tracked: 1,
      untracked: 1,
      beacons: 1,
      message: "tracked one pageview for navigating to topic",
    });
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
