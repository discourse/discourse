import { module, test } from "qunit";
import { resolveTracksAndPlacement } from "discourse/float-kit/components/d-sheet/config-normalizer";

const DEFAULTS = {
  contentPlacement: "bottom",
  tracks: "bottom",
};

module("Unit | Lib | float-kit | d-sheet config normalizer", function () {
  test("resolves Silk's placement and track matrix", function (assert) {
    assert.deepEqual(resolveTracksAndPlacement({}, DEFAULTS), {
      contentPlacement: "bottom",
      tracks: "bottom",
    });
    assert.deepEqual(
      resolveTracksAndPlacement({ contentPlacement: "center" }, DEFAULTS),
      { contentPlacement: "center", tracks: "bottom" }
    );
    assert.deepEqual(
      resolveTracksAndPlacement({ contentPlacement: "top" }, DEFAULTS),
      { contentPlacement: "top", tracks: "top" }
    );
    assert.deepEqual(resolveTracksAndPlacement({ tracks: "right" }, DEFAULTS), {
      contentPlacement: "right",
      tracks: "right",
    });
    assert.deepEqual(
      resolveTracksAndPlacement(
        { contentPlacement: "center", tracks: ["left", "right"] },
        DEFAULTS
      ),
      { contentPlacement: "center", tracks: "horizontal" }
    );
    assert.deepEqual(
      resolveTracksAndPlacement(
        { contentPlacement: "center", tracks: ["top", "bottom"] },
        DEFAULTS
      ),
      { contentPlacement: "center", tracks: "vertical" }
    );
    assert.deepEqual(
      resolveTracksAndPlacement(
        { contentPlacement: "center", tracks: "vertical" },
        DEFAULTS
      ),
      { contentPlacement: "center", tracks: "vertical" }
    );
  });

  test("treats null placement and tracks as omitted", function (assert) {
    assert.deepEqual(
      resolveTracksAndPlacement({ contentPlacement: null }, DEFAULTS),
      DEFAULTS
    );
    assert.deepEqual(
      resolveTracksAndPlacement({ tracks: null }, DEFAULTS),
      DEFAULTS
    );
    assert.deepEqual(
      resolveTracksAndPlacement(
        { contentPlacement: "center", tracks: null },
        DEFAULTS
      ),
      { contentPlacement: "center", tracks: "bottom" }
    );
  });

  test("throws for Silk's invalid placement and track matrix", function (assert) {
    const invalidConfigurations = [
      { contentPlacement: "top", tracks: "bottom" },
      { contentPlacement: "bottom", tracks: "top" },
      { tracks: ["top", "bottom"] },
      { contentPlacement: "left", tracks: "right" },
      { contentPlacement: "right", tracks: "left" },
      { tracks: ["left", "right"] },
    ];

    for (const configuration of invalidConfigurations) {
      const placement = configuration.contentPlacement ?? null;

      assert.throws(
        () => resolveTracksAndPlacement(configuration, DEFAULTS),
        new Error(
          `'placement' prop value '${placement}' cannot be used with 'tracks' prop value '${configuration.tracks}'.`
        ),
        `${placement} placement with ${configuration.tracks} tracks throws`
      );
    }
  });
});
