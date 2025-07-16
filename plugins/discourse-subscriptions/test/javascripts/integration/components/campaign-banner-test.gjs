import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender from "discourse/tests/helpers/create-pretender";
import sinon from "sinon";
import CampaignBanner from "discourse/plugins/discourse-subscriptions/discourse/components/campaign-banner";

module("Subscriptions | campaign-banner", function (hooks) {
  setupRenderingTest(hooks);

  test("does not make AJAX request when plugin is disabled", async function (assert) {
    // Set up pretender to track requests
    let requestCount = 0;
    pretender.get("/s/contributors", () => {
      requestCount++;
      return [200, { "Content-Type": "application/json" }, "[]"];
    });

    // Set site settings
    this.owner.lookup("service:site-settings").discourse_subscriptions_enabled = false;
    this.owner.lookup("service:site-settings").discourse_subscriptions_campaign_enabled = true;
    this.owner.lookup("service:site-settings").discourse_subscriptions_campaign_show_contributors = true;

    // Mock current user
    this.owner.lookup("service:current-user").setProperties({
      id: 1,
      username: "testuser",
    });

    // Mock site settings for show_campaign_banner
    this.owner.lookup("service:site").setProperties({
      show_campaign_banner: true,
    });

    // Mock router with a valid route using sinon stub
    sinon.stub(this.owner.lookup("service:router"), "currentRouteName").value("discovery.latest");

    await render(<template><CampaignBanner /></template>);

    assert.strictEqual(
      requestCount,
      0,
      "No AJAX request is made when plugin is disabled"
    );
  });

  test("renders banner and makes AJAX request when all conditions are met", async function (assert) {
    // Set up pretender to track requests and return mock data
    let requestCount = 0;
    let ajaxUrl = null;
    const mockContributors = [
      { id: 1, username: "contributor1", name: "Contributor One" },
      { id: 2, username: "contributor2", name: "Contributor Two" },
    ];

    pretender.get("/s/contributors", (request) => {
      requestCount++;
      ajaxUrl = request.url;
      return [200, { "Content-Type": "application/json" }, JSON.stringify(mockContributors)];
    });

    // Set site settings - all enabled
    this.owner.lookup("service:site-settings").discourse_subscriptions_enabled = true;
    this.owner.lookup("service:site-settings").discourse_subscriptions_campaign_enabled = true;
    this.owner.lookup("service:site-settings").discourse_subscriptions_campaign_show_contributors = true;
    this.owner.lookup("service:site-settings").discourse_subscriptions_campaign_goal = 100;
    this.owner.lookup("service:site-settings").discourse_subscriptions_campaign_amount_raised = 50;
    this.owner.lookup("service:site-settings").discourse_subscriptions_campaign_type = "Amount";
    this.owner.lookup("service:site-settings").discourse_subscriptions_currency = "USD";

    // Mock current user
    this.owner.lookup("service:current-user").setProperties({
      id: 1,
      username: "testuser",
    });

    // Mock site settings for show_campaign_banner
    this.owner.lookup("service:site").setProperties({
      show_campaign_banner: true,
    });

    // Mock router with a valid route using sinon stub
    sinon.stub(this.owner.lookup("service:router"), "currentRouteName").value("discovery.latest");

    await render(<template><CampaignBanner /></template>);

    // Verify the banner is rendered
    assert.dom(".campaign-banner").exists("Campaign banner is rendered");
    assert.dom(".campaign-banner-info-header").exists("Campaign banner header is rendered");
    assert.dom(".campaign-banner-progress").exists("Campaign banner progress is rendered");

    // Verify AJAX request was made
    assert.strictEqual(
      requestCount,
      1,
      "AJAX request is made when all conditions are met"
    );
    assert.strictEqual(
      ajaxUrl,
      "/s/contributors",
      "AJAX request is made to the correct URL"
    );

    // Wait for the AJAX request to complete and verify contributors are shown
    await new Promise(resolve => setTimeout(resolve, 0));

    // The contributors should be rendered in the template
    assert.dom(".campaign-banner-progress-users").exists("Contributors section is rendered");
  });
});