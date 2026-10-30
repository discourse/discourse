import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
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

  test("the back button jumps to the last read post", async function (assert) {
    const topic = createMegaTopic(this, {
      last_read_post_id: 5500,
      last_read_post_number: 55,
    });
    const jumpToIndex = sinon.spy();

    await render(
      <template>
        <TopicTimeline
          @enteredIndex={{10}}
          @jumpToIndex={{jumpToIndex}}
          @model={{topic}}
        />
      </template>
    );
    await click(".timeline-last-read .back-button");

    assert.true(jumpToIndex.calledOnceWith(55));
  });

  test("shows the total posts count only when it fits", async function (assert) {
    const topic = createMegaTopic(this, { highest_post_number: 10_050 });
    const jumpTop = () => {};
    const sameLine = () => {
      const [current, total] = document.querySelectorAll(
        ".timeline-replies span"
      );
      return current.offsetTop === total.offsetTop;
    };

    await render(
      <template>
        <TopicTimeline @enteredIndex={{5000}} @model={{topic}} />
      </template>
    );
    assert.dom(".timeline-replies").hasText("5001 / 10050");
    assert.true(sameLine(), "the total fits next to the current post");

    await render(
      <template>
        <TopicTimeline
          @enteredIndex={{5000}}
          @fullscreen={{true}}
          @jumpTop={{jumpTop}}
          @model={{topic}}
        />
      </template>
    );
    assert.false(sameLine(), "the total wraps out of view");
  });
});
