import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";

acceptance("Video Placeholder Test", function () {
  test("placeholder shows up on posts with videos", async function (assert) {
    await visit("/t/54081");

    const postWithVideo = document.querySelector(
      ".video-placeholder-container"
    );
    assert.ok(
      postWithVideo.hasAttribute("data-video-src"),
      "Video placeholder should have the 'data-video-src' attribute"
    );

    const overlay = postWithVideo.querySelector(".video-placeholder-overlay");

    assert.notOk(exists("video"), "The video element does not exist yet");

    await click(overlay);

    assert.ok(exists(".video-container"), "The video container appears");

    assert.ok(exists("video"), "The video element appears");
  });
});
