import { getOwner } from "@ember/owner";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import TopicProgress from "discourse/components/topic-progress";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | topic-progress", function (hooks) {
  setupRenderingTest(hooks);

  test("shows the back button on mega topics", async function (assert) {
    const topic = getOwner(this).lookup("service:store").createRecord("topic", {
      id: 1,
      highest_post_number: 100,
      last_read_post_id: 5500,
      last_read_post_number: 80,
    });
    topic.postStream.isMegaTopic = true;

    await render(<template><TopicProgress @topic={{topic}} /></template>);

    assert.dom(".progress-back").exists();
  });
  for (const docked of [false, true]) {
    test(`uses ${docked ? "the final post" : "scroll progress"} when ${docked ? "docked" : "undocked"} with mobile navigation disabled`, async function (assert) {
      this.siteSettings.mobile_footer_navigation = false;
      this.docked = docked;
      this.topic = {
        currentPost: 3,
        postStream: { loaded: true, filteredPostsCount: 10 },
      };

      await render(
        <template>
          <TopicProgress @docked={{this.docked}} @topic={{this.topic}} />
        </template>
      );

      this.owner
        .lookup("service:app-events")
        .trigger("topic:current-post-scrolled", {
          postIndex: 3,
          percent: 0.3,
        });
      await settled();

      assert
        .dom("#topic-progress .nums")
        .hasText(
          `${docked ? 10 : 3} / 10`,
          "the counter preserves the existing docked behavior"
        );
      assert
        .dom("#topic-progress")
        .hasAttribute(
          "style",
          `--progress-bg-width: ${docked ? 100 : "30.00"}%`,
          "the fill preserves the existing docked behavior"
        );
    });
  }
});
