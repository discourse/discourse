import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { PLUGIN_API_VERSION, withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("More topics - Plugin API", function (needs) {
  needs.user();

  test("displays the tabs", async function (assert) {
    withPluginApi(PLUGIN_API_VERSION, (api) => {
      api.registerMoreTopicsTab({
        id: "my-tab",
        name: "News",
        component: <template>hello there!</template>,
        condition: ({ topic, context }) =>
          context === "topic" && topic.id === 280,
      });

      api.registerMoreTopicsTab({
        id: "my-pm-tab",
        name: "Other",
        component: <template>hi!</template>,
        condition: ({ context }) => context === "pm",
      });
    });

    await visit("/t/-/280");
    assert.dom(".more-topics__container li").exists({ count: 2 });
    assert.dom(".more-topics__container li:last-of-type").hasText("News");

    await click(`.more-topics__container button[title="News"]`);
    assert.dom(".more-topics__lists").hasText("hello there!");

    await visit("/t/-/12");
    assert.dom(".more-topics__container li").exists({ count: 2 });
    assert.dom(".more-topics__container li:last-of-type").hasText("Other");

    await click(`.more-topics__container button[title="Other"]`);
    assert.dom(".more-topics__lists").hasText("hi!");

    await visit("/t/-/54077");
    assert.dom(".more-topics__container li").doesNotExist();
    assert.dom(".more-topics__container #suggested-topics-title").exists();
  });
});
