import { getOwner } from "@ember/owner";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { ajax } from "discourse/lib/ajax";
import pretender from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const trackViewHeaderName = "Discourse-Track-View";

function setupPretender(server, helper) {
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

function assertRequests({ assert, tracked, untracked, message }) {
  let trackedCount = 0,
    untrackedCount = 0;

  const requests = pretender.handledRequests;
  requests.forEach((request) => {
    if (request.requestHeaders[trackViewHeaderName]) {
      trackedCount++;
    } else {
      untrackedCount++;
    }
  });

  assert.strictEqual(trackedCount, tracked, `${message} (tracked)`);
  assert.strictEqual(untrackedCount, untracked, `${message} (untracked)`);

  pretender.handledRequests = [];
}

acceptance("Page tracking - loading slider", function (needs) {
  needs.user();
  needs.pretender(setupPretender);

  test("sets the discourse-track-view header correctly", async function (assert) {
    setupFakeAnalytics(this);

    assertRequests({
      assert,
      tracked: 0,
      untracked: 0,
      message: "no requests before app boot",
    });

    await visit("/");
    assertRequests({
      assert,
      tracked: 0,
      untracked: 2,
      message: "no ajax tracked for initial page load",
    });

    await click("#site-logo");
    assertRequests({
      assert,
      tracked: 1,
      untracked: 1,
      message: "tracked one pageview for reloading latest",
    });

    await visit("/t/-/280");
    assertRequests({
      assert,
      tracked: 1,
      untracked: 1,
      message: "tracked one pageview for navigating to topic",
    });
  });
});

acceptance("Page tracking - loading spinner", function (needs) {
  needs.user();
  needs.pretender(setupPretender);
  needs.settings({
    page_loading_indicator: "spinner",
  });

  test("sets the discourse-track-view header correctly", async function (assert) {
    setupFakeAnalytics(this);

    assertRequests({
      assert,
      tracked: 0,
      untracked: 0,
      message: "no requests before app boot",
    });

    await visit("/");
    assertRequests({
      assert,
      tracked: 0,
      untracked: 2,
      message: "no ajax tracked for initial page load",
    });

    await click("#site-logo");
    assertRequests({
      assert,
      tracked: 1,
      untracked: 1,
      message: "tracked one pageview for reloading latest",
    });

    await visit("/t/-/280");
    assertRequests({
      assert,
      tracked: 1,
      untracked: 1,
      message: "tracked one pageview for navigating to topic",
    });
  });
});
