import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import TopicTimeline from "discourse/components/topic-timeline";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const POSTS_COUNT = 100;

function createMegaTopic(context, attrs = {}) {
  const topic = getOwner(context)
    .lookup("service:store")
    .createRecord("topic", {
      id: 1,
      highest_post_number: POSTS_COUNT,
      ...attrs,
    });
  topic.postStream.isMegaTopic = true;
  return topic;
}

module("Integration | Component | topic-timeline", function (hooks) {
  setupRenderingTest(hooks);

  test("fullscreen hides the summary button and shows the last post excerpt", async function (assert) {
    this.siteSettings.summary_timeline_button = true;
    const topic = createMegaTopic(this, { has_summary: true });
    sinon.stub(topic.postStream, "excerpt").resolves({ excerpt: "Last post" });
    const jumpTop = () => {};

    await render(
      <template>
        <TopicTimeline
          @enteredIndex={{99}}
          @fullscreen={{true}}
          @jumpTop={{jumpTop}}
          @model={{topic}}
        />
      </template>
    );

    assert.dom(".show-summary").doesNotExist();
    assert.dom(".post-excerpt").hasText("Last post");
  });
});
