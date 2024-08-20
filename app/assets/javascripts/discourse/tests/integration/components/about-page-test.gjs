import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import AboutPage from "discourse/components/about-page";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function createModelObject({
  title = "My Forums",
  admins = [],
  moderators = [],
  stats = {},
}) {
  return {
    title,
    admins,
    moderators,
    stats,
  };
}

module("Integration | Component | about-page", function (hooks) {
  setupRenderingTest(hooks);

  test("custom site activities registered via the plugin API", async function (assert) {
    withPluginApi("1.37.0", (api) => {
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
});
