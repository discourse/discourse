import { click, render, triggerEvent } from "@ember/test-helpers";
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

  test("commits to a page derived from page_count", async function (assert) {
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

    assert.deepEqual(
      jumpToRootPage.lastCall.args,
      [3, null, 19],
      "uses page_count and preserves the target offset"
    );
  });

  test("accounts for pinned roots when committing to an exact offset", async function (assert) {
    const jumpToRootPage = sinon.spy();
    this.setProperties({
      firstLoadedPage: 0,
      jumpToRootPage,
      loadedPostNumbers: [10],
      summary: {
        total: 100,
        page_size: 20,
        page_count: 5,
        pinned_count: 10,
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
    await pointerAt(rail, "pointerdown", 0.75);
    await pointerAt(rail, "pointerup", 0.75);

    assert.deepEqual(
      jumpToRootPage.lastCall.args,
      [3, null, 5],
      "lands at the target offset within the unpinned page"
    );
  });

  test("endpoint labels jump to the start and end", async function (assert) {
    const jumpToRootPage = sinon.spy();
    this.setProperties({
      firstLoadedPage: 0,
      jumpToRootPage,
      loadedPostNumbers: [10],
      summary: {
        total: 100,
        page_size: 20,
        page_count: 5,
        pinned_count: 10,
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

    await click(".nested-topic-timeline__endpoint--start");
    assert.deepEqual(
      jumpToRootPage.lastCall.args,
      [0, null, 0],
      "start label jumps to the first root"
    );

    await click(".nested-topic-timeline__endpoint--end");
    assert.deepEqual(
      jumpToRootPage.lastCall.args,
      [4, null, 9],
      "end label jumps to the last root"
    );
  });
});
