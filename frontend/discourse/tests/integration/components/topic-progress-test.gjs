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
    assert
      .dom("#topic-progress-wrapper")
      .hasAttribute(
        "role",
        "navigation",
        "the back button has a navigation landmark"
      );
  });

  test("omits the landmark when the desktop counter is hidden", async function (assert) {
    const topic = {
      currentPost: 1,
      postStream: { loaded: true, filteredPostsCount: 1 },
    };

    await render(<template><TopicProgress @topic={{topic}} /></template>);

    assert
      .dom("#topic-progress")
      .isNotVisible("the single-post counter is hidden");
    assert
      .dom("#topic-progress-wrapper")
      .doesNotHaveAttribute("role", "the empty wrapper is not a landmark");
    assert
      .dom("#topic-progress-wrapper")
      .doesNotHaveAttribute(
        "aria-label",
        "the empty wrapper has no accessible name"
      );
  });

  test("names the progress control and updates it as the reader scrolls", async function (assert) {
    const topic = {
      currentPost: 3,
      postStream: { loaded: true, filteredPostsCount: 10 },
    };
    const appEvents = this.owner.lookup("service:app-events");

    await render(<template><TopicProgress @topic={{topic}} /></template>);

    assert
      .dom("#topic-progress-wrapper[role='navigation']")
      .hasAria("label", "Topic progress", "the navigation landmark has a name");
    assert
      .dom("button#topic-progress")
      .hasAria(
        "label",
        "Topic progress",
        "the button has a name before the first scroll event"
      );

    appEvents.trigger("topic:current-post-scrolled", {
      postIndex: 3,
      percent: 0.3,
    });
    await settled();

    assert
      .dom("#topic-progress .nums")
      .hasText("3 / 10", "the counter shows the current position");
    assert
      .dom("#topic-progress")
      .hasAria(
        "label",
        "Topic progress, 3 of 10",
        "the button name includes the current position"
      )
      .hasAttribute(
        "style",
        "--progress-bg-width: 30.00%",
        "the fill matches the current position"
      );

    appEvents.trigger("topic:current-post-scrolled", {
      postIndex: 10,
      percent: 1,
    });
    await settled();

    assert
      .dom("#topic-progress")
      .hasAria(
        "label",
        "Topic progress, 10 of 10",
        "the button name follows the reader to the last post"
      );
  });
});
