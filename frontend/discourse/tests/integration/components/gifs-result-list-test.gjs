import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import GifsResultList from "discourse/components/gifs/result-list";
import loadMiniMasonry from "discourse/lib/load-minimasonry";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import stubIntersectionObserver from "discourse/tests/helpers/stub-intersection-observer";

module("Integration | Component | GifsResultList", function (hooks) {
  setupRenderingTest(hooks);

  test("waits for masonry layout before observing the pagination sentinel", async function (assert) {
    const observations = stubIntersectionObserver();
    const MiniMasonry = await loadMiniMasonry();
    const observationCounts = [];
    const layout = MiniMasonry.prototype.layout;
    sinon.stub(MiniMasonry.prototype, "layout").callsFake(function (...args) {
      observationCounts.push(observations.length);
      return layout.apply(this, args);
    });
    const content = [
      {
        title: "A GIF",
        preview: "/images/emoji/twitter/smile.png",
        width: 200,
        height: 150,
      },
    ];
    const loadMore = () => {};

    await render(
      <template>
        <GifsResultList
          @content={{content}}
          @loading={{false}}
          @loadMore={{loadMore}}
        />
      </template>
    );

    assert.true(observationCounts.length > 0, "lays out the results");
    assert.true(
      observationCounts.every((count) => count === 0),
      "does not observe the sentinel before the initial layout finishes"
    );
    assert.strictEqual(
      observations.length,
      1,
      "observes the sentinel after layout finishes"
    );
  });
});
