import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import A11yLiveRegions from "discourse/components/a11y/live-regions";
import { disableClearA11yAnnouncementsInTests } from "discourse/services/a11y";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | a11y/live-regions", function (hooks) {
  setupRenderingTest(hooks);

  test("renders polite and assertive live regions", async function (assert) {
    await render(<template><A11yLiveRegions /></template>);

    assert
      .dom("#a11y-announcements-polite")
      .exists("polite announcements element exists");
    assert
      .dom("#a11y-announcements-assertive")
      .exists("assertive announcements element exists");

    assert.dom("#a11y-announcements-polite").hasAttribute("role", "status");
    assert
      .dom("#a11y-announcements-polite")
      .hasAttribute("aria-live", "polite");
    assert
      .dom("#a11y-announcements-polite")
      .hasAttribute("aria-atomic", "true");

    assert.dom("#a11y-announcements-assertive").hasAttribute("role", "alert");
    assert
      .dom("#a11y-announcements-assertive")
      .hasAttribute("aria-live", "assertive");
    assert
      .dom("#a11y-announcements-assertive")
      .hasAttribute("aria-atomic", "true");
  });

  test("displays assertive messages", async function (assert) {
    disableClearA11yAnnouncementsInTests();

    const a11y = getOwner(this).lookup("service:a11y");
    a11y.announce("Test assertive message", "assertive", 500);

    await render(<template><A11yLiveRegions /></template>);

    assert
      .dom("#a11y-announcements-assertive")
      .hasText("Test assertive message", "displays assertive message");
  });

  test("displays polite messages", async function (assert) {
    disableClearA11yAnnouncementsInTests();

    const a11y = getOwner(this).lookup("service:a11y");
    a11y.announce("Test polite message", "polite", 500);

    await render(<template><A11yLiveRegions /></template>);

    assert
      .dom("#a11y-announcements-polite")
      .hasText("Test polite message", "displays polite message");
  });
});
