import {
  currentRouteName,
  getSettledState,
  settled,
  visit,
  waitUntil,
} from "@ember/test-helpers";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import pretender from "discourse/tests/helpers/create-pretender";
import AboutFixtures from "discourse/tests/fixtures/about";

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

    assert.strictEqual(currentRouteName(), "about_loading");
    assert.dom("#main-outlet > div.spinner").exists();
    assert.dom(".loading-indicator-container").doesNotExist();

    pretender.resolve(aboutRequest);
    await settled();

    assert.strictEqual(currentRouteName(), "about");
    assert.dom("#main-outlet > div.spinner").doesNotExist();
    assert.dom("#main-outlet section.about").exists();
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
    assert.dom("#main-outlet > div.spinner").doesNotExist();

    await waitUntil(() =>
      query(".loading-indicator-container").classList.contains("loading")
    );

    pretender.resolve(aboutRequest);

    await waitUntil(() =>
      query(".loading-indicator-container").classList.contains("done")
    );

    await settled();

    assert.strictEqual(currentRouteName(), "about");
    assert.dom("#main-outlet section.about").exists();
  });
});
