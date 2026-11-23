import { module, test } from "qunit";
import {
  handleOffset,
  shellTracks,
  widthForHandleOffset,
} from "discourse/lib/page-shell-geometry";

function geometry(overrides = {}) {
  return {
    width: "centered",
    contextPosition: "start",
    resize: "grow",
    viewportWidth: 1920,
    shellWidth: 1905,
    mainMaxWidth: 1158,
    mainMinWidth: 448,
    composerWidth: 0,
    railWidth: 56,
    navigation: {
      mode: "open",
      width: 260,
      maxWidth: 400,
      referenceWidth: 260,
      forcedHidden: false,
    },
    context: {
      mode: "open",
      width: 300,
      maxWidth: 1000,
      referenceWidth: 300,
      forcedHidden: false,
    },
    ...overrides,
  };
}

module("Unit | Lib | page shell geometry", function () {
  test("tracks fill the shell in every policy", function (assert) {
    for (const [width, resize] of [
      ["centered", "grow"],
      ["centered", "content"],
      ["full", "grow"],
    ]) {
      const tracks = shellTracks(geometry({ width, resize }));
      const total = Object.values(tracks).reduce((sum, track) => sum + track);
      assert.strictEqual(total, 1905, `${width}/${resize}`);
    }
  });

  test("a centered shell moves the handle by half the width change", function (assert) {
    const start = geometry();
    const offset = handleOffset(start, "navigation");
    const wider = handleOffset(
      geometry({ navigation: { ...start.navigation, width: 300 } }),
      "navigation"
    );
    assert.strictEqual(wider - offset, 20);
    assert.strictEqual(
      widthForHandleOffset(start, "navigation", offset + 20, 200, 400),
      300,
      "the width doubles the pointer travel"
    );
  });

  test("the mapping stays continuous when the shell reaches the viewport edge", function (assert) {
    const start = geometry();
    const offset = handleOffset(start, "context");
    // Half speed until the start gutter closes at 502px, then one to one.
    const width = widthForHandleOffset(
      start,
      "context",
      offset + 200,
      200,
      1000
    );
    assert.strictEqual(width, 601);
    assert.strictEqual(
      handleOffset(
        geometry({ context: { ...start.context, width } }),
        "context"
      ),
      offset + 200
    );
  });

  test("taking space from main keeps the shell edge and maps one to one", function (assert) {
    const start = geometry({ resize: "content" });
    const before = shellTracks(start);
    const after = shellTracks(
      geometry({
        resize: "content",
        navigation: { ...start.navigation, width: 340 },
      })
    );
    assert.strictEqual(after.offset, before.offset);
    assert.strictEqual(after.main, before.main - 80);
    assert.strictEqual(
      widthForHandleOffset(
        start,
        "navigation",
        handleOffset(start, "navigation") + 80,
        200,
        400
      ),
      340
    );
  });

  test("taking space from main grows the shell once main reaches its minimum", function (assert) {
    const tracks = shellTracks(
      geometry({
        resize: "content",
        navigation: { ...geometry().navigation, width: 400 },
        context: { ...geometry().context, width: 1000 },
      })
    );
    assert.strictEqual(tracks.main, 448);
    assert.strictEqual(tracks.offset, (1920 - (400 + 1000 + 448)) / 2);
  });

  test("full width maps one to one and ignores the resize policy", function (assert) {
    const start = geometry({ width: "full", resize: "content" });
    assert.strictEqual(shellTracks(start).offset, 0);
    assert.strictEqual(
      widthForHandleOffset(
        start,
        "context",
        handleOffset(start, "context") + 50,
        200,
        1000
      ),
      350
    );
  });

  test("end Context measures its handle from the end gutter and composer", function (assert) {
    const start = geometry({ contextPosition: "end", composerWidth: 100 });
    const tracks = shellTracks(start);
    const offset = handleOffset(start, "context");

    assert.strictEqual(
      offset,
      tracks.end + 100 + 300,
      "The offset starts at the shell's inline end"
    );
    assert.strictEqual(
      widthForHandleOffset(start, "context", offset + 20, 200, 1000),
      340,
      "The centered shell absorbs half the pointer travel"
    );
  });

  test("bounds hold when the pointer travels past them", function (assert) {
    const start = geometry();
    assert.strictEqual(
      widthForHandleOffset(start, "navigation", 99999, 200, 400),
      400
    );
    assert.strictEqual(
      widthForHandleOffset(start, "navigation", -99999, 200, 400),
      200
    );
  });

  test("hidden and forced-hidden panels take no track or reference space", function (assert) {
    const tracks = shellTracks(
      geometry({
        resize: "content",
        navigation: { ...geometry().navigation, mode: "hidden" },
        context: { ...geometry().context, forcedHidden: true },
      })
    );
    assert.strictEqual(tracks.navigation, 0);
    assert.strictEqual(tracks.context, 0);
    assert.strictEqual(tracks.main, 1158);
  });
});
