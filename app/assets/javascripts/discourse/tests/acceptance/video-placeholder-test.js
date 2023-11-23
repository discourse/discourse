import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

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

    assert.dom("video").doesNotExist("The video element does not exist yet");

    await click(overlay); // Play button is clicked

    assert.dom(".video-container").exists("The video container appears");

    assert
      .dom(postWithVideo)
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

    const video = postWithVideo.querySelector("video");
    video.play = function () {}; // We don't actually want the video to play in our test
    const canPlayEvent = new Event("canplay");
    video.dispatchEvent(canPlayEvent);

    assert
      .dom(video)
      .hasStyle({ display: "block" }, "The video is no longer hidden");
    assert.dom(".video-placeholder-wrapper").doesNotExist();
  });
});
