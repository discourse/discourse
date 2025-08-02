import { getOwner } from "@ember/owner";
import {
  currentRouteName,
  getSettledState,
  settled,
  visit,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { test } from "qunit";
import AboutFixtures from "discourse/tests/fixtures/about";
import pretender from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const SPINNER_SELECTOR =
  "#main-outlet-wrapper .route-loading-spinner div.spinner";

// Like settled(), but ignores timers, transitions and network requests
function isMostlySettled() {
  let { hasRunLoop, hasPendingWaiters, isRenderPending } = getSettledState();

  if (hasRunLoop || hasPendingWaiters || isRenderPending) {
    return false;
  } else {
    return true;
  }
}

function mostlySettled() {
  return waitUntil(isMostlySettled);
}

acceptance("Page Loading Indicator", function (needs) {
  let pendingRequest;
  let resolvePendingRequest;

  needs.pretender((server, helper) => {
    pendingRequest = new Promise(
      (resolve) => (resolvePendingRequest = resolve)
    );

    pretender.get(
      "/about.json",
      (request) => {
        resolvePendingRequest(request);
        return helper.response(AboutFixtures["about.json"]);
      },
      true // Require manual resolution
    );
  });

  test("it works in 'spinner' mode", async function (assert) {
    this.siteSettings.page_loading_indicator = "spinner";

    await visit("/");
    visit("/about");

    const aboutRequest = await pendingRequest;
    await mostlySettled();

    assert.strictEqual(currentRouteName(), "discovery.latest");
    assert.dom(SPINNER_SELECTOR).exists();
    assert.dom(".loading-indicator-container").doesNotExist();

    pretender.resolve(aboutRequest);
    await settled();

    assert.strictEqual(currentRouteName(), "about");
    assert.dom(SPINNER_SELECTOR).doesNotExist();
    assert.dom("#main-outlet .about__main-content").exists();
  });

  test("it works in 'slider' mode", async function (assert) {
    this.siteSettings.page_loading_indicator = "slider";

    await visit("/");

    assert.dom(".loading-indicator-container").exists();
    assert.dom(".loading-indicator-container").hasClass("ready");

    visit("/about");

    const aboutRequest = await pendingRequest;
    await mostlySettled();

    assert.strictEqual(currentRouteName(), "discovery.latest");
    assert.dom(SPINNER_SELECTOR).doesNotExist();

    await waitFor(".loading-indicator-container.loading");

    pretender.resolve(aboutRequest);

    await waitFor(".loading-indicator-container.done");
    await settled();

    assert.strictEqual(currentRouteName(), "about");
    assert.dom("#main-outlet .about__main-content").exists();
  });

  test("it only performs one slide during nested loading events", async function (assert) {
    this.siteSettings.page_loading_indicator = "slider";

    await visit("/");

    const service = getOwner(this).lookup("service:loading-slider");
    service.on("stateChanged", (loading) => {
      assert.step(`loading: ${loading}`);
    });

    await visit("/u/eviltrout/activity");

    assert.verifySteps(["loading: true", "loading: false"]);
  });
});
