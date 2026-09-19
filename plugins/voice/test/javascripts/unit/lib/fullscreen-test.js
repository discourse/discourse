import { module, test } from "qunit";
import {
  toggleFullscreen,
  toggleTileFullscreen,
} from "discourse/plugins/voice/discourse/lib/voice/fullscreen";

// Nothing is fullscreen during these tests, so toggle always takes the enter
// path; each case exposes only one browser's API to assert the fallback order.
module("Voice | Unit | Lib | fullscreen", function () {
  test("prefers the standard Fullscreen API on the tile", function (assert) {
    let called = false;
    const tile = {
      requestFullscreen() {
        called = true;
        return Promise.resolve();
      },
    };

    toggleTileFullscreen(tile);
    assert.true(called, "calls requestFullscreen on the tile");
  });

  test("falls back to the webkit-prefixed API", function (assert) {
    let called = false;
    const tile = {
      webkitRequestFullscreen() {
        called = true;
      },
    };

    toggleTileFullscreen(tile);
    assert.true(
      called,
      "calls webkitRequestFullscreen when the standard API is absent"
    );
  });

  test("falls back to the iOS video element API", function (assert) {
    let called = false;
    const video = {
      webkitEnterFullscreen() {
        called = true;
      },
    };
    const tile = {
      querySelector() {
        return video;
      },
    };

    toggleTileFullscreen(tile);
    assert.true(
      called,
      "enters fullscreen on the <video> when only the iOS API exists"
    );
  });

  test("does nothing without a tile", function (assert) {
    toggleTileFullscreen(null);
    assert.true(true, "returns without throwing");
  });

  test("the generic toggle never falls back to a descendant video", function (assert) {
    let videoCalled = false;
    const element = {
      querySelector() {
        return {
          webkitEnterFullscreen() {
            videoCalled = true;
          },
        };
      },
    };

    toggleFullscreen(element);
    assert.false(
      videoCalled,
      "fullscreening the gallery container does not hijack a single video"
    );
  });
});
