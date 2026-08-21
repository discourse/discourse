import { module, test } from "qunit";
import {
  rootIndexForLogicalOffset,
  rootSpacerHeights,
  shouldShowTimeline,
} from "discourse/components/nested";

module("Unit | Component | Nested", function () {
  test("shows the timeline for a single root on a wide desktop", function (assert) {
    assert.true(
      shouldShowTimeline({
        desktopView: true,
        contextMode: false,
        wideViewport: true,
        rootCount: 1,
        loadedRootCount: 1,
      }),
      "keeps within-branch navigation available for deeply nested topics"
    );
  });

  test("hides the timeline when it cannot be used", function (assert) {
    assert.false(
      shouldShowTimeline({
        desktopView: true,
        contextMode: false,
        wideViewport: true,
        rootCount: 0,
        loadedRootCount: 0,
      }),
      "hides the timeline when the topic has no roots"
    );
    assert.false(
      shouldShowTimeline({
        desktopView: true,
        contextMode: true,
        wideViewport: true,
        rootCount: 1,
        loadedRootCount: 1,
      }),
      "hides the timeline in single-thread context mode"
    );
    assert.false(
      shouldShowTimeline({
        desktopView: true,
        contextMode: false,
        wideViewport: false,
        rootCount: 1,
        loadedRootCount: 1,
      }),
      "hides the timeline when its gutter does not fit"
    );
  });

  test("reserves estimated space for unloaded roots around the active window", function (assert) {
    assert.deepEqual(
      rootSpacerHeights({
        rootCount: 10_000,
        rootWindowStart: 4_980,
        loadedRootCount: 60,
        rootHeightEstimate: 200,
      }),
      { top: 996_000, bottom: 992_000 },
      "keeps a stable logical document axis without rendering every root"
    );
  });

  test("infers a direct root target anywhere in a large logical axis", function (assert) {
    assert.strictEqual(
      rootIndexForLogicalOffset({
        offset: 1_200_000,
        rootCount: 10_000,
        rootHeightEstimate: 240,
      }),
      5_000,
      "maps a position beyond the old sentinel reach directly to its root"
    );
    assert.strictEqual(
      rootIndexForLogicalOffset({
        offset: 3_000_000,
        rootCount: 10_000,
        rootHeightEstimate: 240,
      }),
      9_999,
      "clamps positions beyond the logical document to the final root"
    );
    assert.strictEqual(
      rootIndexForLogicalOffset({
        offset: 100,
        rootCount: 10_000,
        rootHeightEstimate: 0,
      }),
      null,
      "does not infer a target without a usable height estimate"
    );
  });
});
