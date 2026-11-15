import {
  render,
  triggerKeyEvent,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { openLightbox } from "discourse/lib/lightbox";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { WEBM_BYTES } from "discourse/tests/helpers/media-fixtures";

module("Integration | Lib | openLightbox", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(async function () {
    if (document.querySelector(".pswp")) {
      await triggerKeyEvent(".pswp", "keydown", "Escape");
      await waitUntil(() => !document.querySelector(".pswp"));
    }
  });

  test("opens image slides at the requested index", async function (assert) {
    await render(
      <template>
        <img alt="First" class="first" src="/images/avatar.png" />
        <img alt="Second" class="second" src="/images/avatar.png?2" />
      </template>
    );

    const images = [...this.element.querySelectorAll("img")];
    openLightbox(
      images.map((element) => ({ src: element.src, element })),
      { index: 1 }
    );
    await waitFor(".pswp--open");

    assert
      .dom(
        ".pswp__item[aria-hidden='false'] .pswp__img:not(.pswp__img--placeholder)"
      )
      .hasAttribute("src", /avatar\.png\?2$/);
    assert.dom(".pswp__caption-title").hasText("Second");
  });

  test("renders video slides with native controls", async function (assert) {
    openLightbox([{ type: "video", src: "/uploads/clip.mp4" }]);
    await waitFor("video.pswp__video");

    assert
      .dom("video.pswp__video", document.body)
      .hasAttribute("src", /\/uploads\/clip\.mp4$/);
    assert
      .dom("video.pswp__video", document.body)
      .hasProperty("controls", true);
  });

  test("refocuses the video after its controls are used", async function (assert) {
    openLightbox([{ type: "video", src: "/uploads/clip.mp4" }]);
    await waitFor("video.pswp__video");

    const video = document.querySelector("video.pswp__video");
    video.blur();
    video.dispatchEvent(new Event("play"));

    assert.strictEqual(
      document.activeElement,
      video,
      "keeps Escape reachable after native controls take focus"
    );
  });

  test("resizes an image slide to the loaded image", async function (assert) {
    // no element, so the slide starts from the 800x600 fallback
    openLightbox([{ src: "/images/avatar.png" }]);

    // the resize follows the image's load event, which can come after the slide reports loaded
    await waitUntil(() => {
      const img = document.querySelector(
        ".pswp__img:not(.pswp__img--placeholder)"
      );
      return img?.style.width && img.style.width === img.style.height;
    });
    assert.true(true, "uses the square image's aspect ratio");
  });

  test("resizes a video slide once its metadata loads", async function (assert) {
    const src = URL.createObjectURL(
      new Blob([WEBM_BYTES], { type: "video/webm" })
    );

    try {
      // no element, so the slide starts from the 1280x720 fallback
      openLightbox([{ type: "video", src }]);

      await waitUntil(() => {
        const video = document.querySelector("video.pswp__video");
        return video?.style.width && video.style.width === video.style.height;
      });
      assert.true(true, "uses the square video's aspect ratio");
    } finally {
      URL.revokeObjectURL(src);
    }
  });

  test("settles every call when opened twice quickly", async function (assert) {
    let settled = 0;
    openLightbox([{ src: "/images/avatar.png" }]).then(() => settled++);
    openLightbox([{ src: "/images/avatar.png?2" }]).then(() => settled++);
    await waitUntil(() => window.pswp?.currSlide?.content.state === "loaded");

    assert.dom(".pswp", document.body).exists({ count: 1 });

    await triggerKeyEvent(".pswp", "keydown", "Escape");
    await waitUntil(() => !document.querySelector(".pswp"));
    await waitUntil(() => settled === 2, { timeout: 1000 });
    assert.strictEqual(settled, 2, "neither open is left pending");
  });

  test("resolves when closed with Escape", async function (assert) {
    const closed = openLightbox([{ src: "/images/avatar.png" }]);
    await waitFor(".pswp--open");

    await triggerKeyEvent(".pswp", "keydown", "Escape");
    await closed;
    await waitUntil(() => !document.querySelector(".pswp"));

    assert.dom(".pswp").doesNotExist();
  });
});
