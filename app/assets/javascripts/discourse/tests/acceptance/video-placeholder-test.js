import { click, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Video Placeholder Test", function () {
  test("placeholder shows up on posts with videos", async function (assert) {
    await visit("/t/54081");

    assert
      .dom(".video-placeholder-container")
      .hasAttribute(
        "data-video-src",
        /^\/uploads\/.+/,
        "Video placeholder has the 'data-video-src' attribute"
      );

    assert.dom("video").doesNotExist("The video element does not exist yet");

    await click(".video-placeholder-overlay"); // Play button is clicked

    assert.dom(".video-container").exists("The video container appears");

    assert
      .dom(".video-placeholder-container")
      .hasStyle({ cursor: "auto" }, "The cursor is set back to normal");

    assert
      .dom(".video-placeholder-overlay > div")
      .hasClass("spinner", "has a loading spinner");

    assert.dom("video").exists("The video element appears");

    assert
      .dom("video > source")
      .hasAttribute(
        "src",
        "/uploads/default/original/1X/55508bc98a00f615dbe9bd4c84a253ba4238b021.mp4",
        "Video src is correctly set"
      );

    const video = document.querySelector("video");
    video.play = function () {}; // We don't actually want the video to play in our test
    await triggerEvent(video, "canplay");

    assert
      .dom(video)
      .hasStyle({ display: "block" }, "The video is no longer hidden");
    assert.dom(".video-placeholder-wrapper").doesNotExist();
  });
});
