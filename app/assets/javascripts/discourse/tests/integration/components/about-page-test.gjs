import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import AboutPage from "discourse/components/about-page";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import I18n from "discourse-i18n";

function createModelObject({
  title = "My Forums",
  admins = [],
  moderators = [],
  stats = {},
}) {
  const model = arguments[0] || {};
  return Object.assign(
    {
      title,
      admins,
      moderators,
      stats,
    },
    model
  );
}

module("Integration | Component | about-page", function (hooks) {
  setupRenderingTest(hooks);

  test("custom site activities registered via the plugin API", async function (assert) {
    withPluginApi((api) => {
      api.addAboutPageActivity("my_custom_activity", (periods) => {
        return {
          icon: "eye",
          class: "custom-activity",
          activityText: `${periods["3_weeks"]} my custom activity`,
          period: "in the last 3 weeks",
        };
      });

      api.addAboutPageActivity("another_custom_activity", () => null);
    });

    const model = createModelObject({
      stats: {
        my_custom_activity_3_weeks: 342,
        my_custom_activity_1_year: 123,
        another_custom_activity_1_day: 994,
      },
    });

    await render(<template><AboutPage @model={{model}} /></template>);
    assert
      .dom(".about__activities-item.custom-activity")
      .exists("my_custom_activity is rendered");
    assert
      .dom(".about__activities-item.custom-activity .d-icon-eye")
      .exists("icon for my_custom_activity is rendered");
    assert
      .dom(
        ".about__activities-item.custom-activity .about__activities-item-count"
      )
      .hasText("342 my custom activity");
    assert
      .dom(
        ".about__activities-item.custom-activity .about__activities-item-period"
      )
      .hasText("in the last 3 weeks");
  });

  test("visitor stats are not rendered if they're not available in the model", async function (assert) {
    this.siteSettings.display_eu_visitor_stats = true;
    let model = createModelObject({
      stats: {},
    });

    await render(<template><AboutPage @model={{model}} /></template>);
    assert
      .dom(".about__activities-item.visitors")
      .doesNotExist("visitors stats item is not rendered");

    model = createModelObject({
      stats: {
        eu_visitors_7_days: 13,
        eu_visitors_30_days: 30,
        visitors_7_days: 33,
        visitors_30_days: 103,
      },
    });

    await render(<template><AboutPage @model={{model}} /></template>);
    assert
      .dom(".about__activities-item.visitors")
      .exists("visitors stats item is rendered");
    assert
      .dom(".about__activities-item.visitors .about__activities-item-count")
      .hasText(
        I18n.messageFormat("about.activities.visitors_MF", {
          total_count: 33,
          eu_count: 13,
          total_formatted_number: "33",
          eu_formatted_number: "13",
        })
      );
  });

  test("contact URL", async function (assert) {
    let model = createModelObject({
      contact_url: "www.example.com",
    });

    await render(<template><AboutPage @model={{model}} /></template>);

    assert
      .dom(".about__contact-info a")
      .hasAttribute(
        "href",
        "//www.example.com",
        "appends a double slash if the value doesn't start with a slash or a protocol"
      );

    model.contact_url = "/u/somebody";

    await render(<template><AboutPage @model={{model}} /></template>);

    assert
      .dom(".about__contact-info a")
      .hasAttribute(
        "href",
        "/u/somebody",
        "doesn't append a double slash if the value starts with a slash"
      );

    model.contact_url = "https://example.com";

    await render(<template><AboutPage @model={{model}} /></template>);

    assert
      .dom(".about__contact-info a")
      .hasAttribute(
        "href",
        "https://example.com",
        "doesn't append a double slash if the value starts with a protocol"
      );
  });
});
