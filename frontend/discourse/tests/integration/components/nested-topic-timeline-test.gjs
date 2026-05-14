import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import NestedTopicTimeline from "discourse/components/nested/topic-timeline";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

async function pointerAt(rail, type, progress) {
  const rect = rail.getBoundingClientRect();
  const scroller = rail.querySelector(".timeline-scroller");
  const scrollerHeight = scroller.getBoundingClientRect().height || 50;
  const travel = Math.max(1, rect.height - scrollerHeight);
  const clientY = rect.top + scrollerHeight / 2 + travel * progress;

  await triggerEvent(rail, type, {
    clientY,
    pointerId: 1,
    button: 0,
    buttons: type === "pointerup" ? 0 : 1,
  });
}

module("Integration | Component | nested-topic-timeline", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.clock = sinon.useFakeTimers({ shouldClearNativeTimers: true });
    this.styleEl = document.createElement("style");
    this.styleEl.textContent =
      ".nested-topic-timeline__scrubber { height: 200px; width: 80px; }";
    document.head.appendChild(this.styleEl);
  });

  hooks.afterEach(function () {
    this.clock.restore();
    this.styleEl.remove();
  });

  test("uses entry pages when pinned roots shift indexes", async function (assert) {
    const jumpToRootPage = sinon.spy();
    this.setProperties({
      firstLoadedPage: 0,
      jumpToRootPage,
      loadedPostNumbers: [10],
      summary: {
        total: 3,
        page_size: 2,
        page_count: 1,
        entries: [
          { post_number: 30, total_descendant_count: 0, page: 0 },
          { post_number: 10, total_descendant_count: 0, page: 0 },
          { post_number: 20, total_descendant_count: 0, page: 0 },
        ],
      },
    });

    await render(
      <template>
        <div class="nested-view__roots">
          {{#each this.loadedPostNumbers as |postNumber|}}
            <div class="nested-post --depth-0">
              <article data-post-number={{postNumber}}></article>
            </div>
          {{/each}}
        </div>

        <NestedTopicTimeline
          @summary={{this.summary}}
          @sort="top"
          @firstLoadedPage={{this.firstLoadedPage}}
          @jumpToRootPage={{this.jumpToRootPage}}
        />
      </template>
    );

    const rail = document.querySelector(".nested-topic-timeline__scrubber");
    await pointerAt(rail, "pointerdown", 0.8);
    await pointerAt(rail, "pointerup", 0.8);

    assert.deepEqual(
      jumpToRootPage.lastCall.args,
      [0, 20],
      "uses the server-provided page instead of index / page size"
    );
  });

  test("uses page_count for compact summaries", async function (assert) {
    const jumpToRootPage = sinon.spy();
    this.setProperties({
      firstLoadedPage: 0,
      jumpToRootPage,
      loadedPostNumbers: [10],
      summary: {
        total: 100,
        page_size: 20,
        page_count: 4,
      },
    });

    await render(
      <template>
        <div class="nested-view__roots">
          {{#each this.loadedPostNumbers as |postNumber|}}
            <div class="nested-post --depth-0">
              <article data-post-number={{postNumber}}></article>
            </div>
          {{/each}}
        </div>

        <NestedTopicTimeline
          @summary={{this.summary}}
          @sort="top"
          @firstLoadedPage={{this.firstLoadedPage}}
          @jumpToRootPage={{this.jumpToRootPage}}
        />
      </template>
    );

    const rail = document.querySelector(".nested-topic-timeline__scrubber");
    await pointerAt(rail, "pointerdown", 0.99);
    await pointerAt(rail, "pointerup", 0.99);

    assert.deepEqual(jumpToRootPage.lastCall.args, [3], "uses page_count");
  });
});
