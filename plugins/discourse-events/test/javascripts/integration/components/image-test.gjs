import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import Image from "discourse/plugins/discourse-events/discourse/components/discourse-post-event/image";

function upload(width, height, dominantColor = "2A292A") {
  return {
    dominant_color: dominantColor,
    height,
    url: "/uploads/default/original/1X/event.jpeg",
    width,
  };
}

module("Integration | Component | Image", function (hooks) {
  setupRenderingTest(hooks);

  test("crops images between 4:3 and 2:1 into the banner", async function (assert) {
    const imageUpload = upload(1600, 900);

    await render(
      <template>
        <Image
          @imageUpload={{imageUpload}}
          @linkToPost={{true}}
          @postUrl="/t/1"
        />
      </template>
    );

    assert
      .dom(".event-image")
      .doesNotHaveClass("--side", "the image stays in the banner")
      .doesNotHaveClass("--letterboxed", "the image is cropped")
      .doesNotHaveAttribute("style");
  });

  test("letterboxes near-square images on their dominant color", async function (assert) {
    const imageUpload = upload(800, 800);

    await render(
      <template>
        <Image
          @imageUpload={{imageUpload}}
          @linkToPost={{true}}
          @postUrl="/t/1"
        />
      </template>
    );

    assert.dom(".event-image").hasClass("--letterboxed").hasStyle({
      "--event-image-color": "#2A292A",
      "--event-image-height": "800px",
      "--event-image-ratio": "1",
    });
  });

  test("letterboxes images wider than 2:1", async function (assert) {
    const imageUpload = upload(1500, 500);

    await render(
      <template>
        <Image
          @imageUpload={{imageUpload}}
          @linkToPost={{true}}
          @postUrl="/t/1"
        />
      </template>
    );

    assert.dom(".event-image").hasClass("--letterboxed");
  });

  test("puts portrait images in the side column", async function (assert) {
    const imageUpload = upload(800, 1200);

    await render(
      <template>
        <Image
          @imageUpload={{imageUpload}}
          @linkToPost={{true}}
          @postUrl="/t/1"
        />
      </template>
    );

    assert
      .dom(".event-image")
      .hasClass("--side")
      .doesNotHaveClass("--letterboxed")
      .hasStyle(
        { "--event-image-color": "#2A292A" },
        "the color is ready for the letterboxed layout on narrow screens"
      );
  });

  test("ignores a malformed dominant color", async function (assert) {
    const imageUpload = upload(800, 800, "red; display: none");

    await render(
      <template>
        <Image
          @imageUpload={{imageUpload}}
          @linkToPost={{true}}
          @postUrl="/t/1"
        />
      </template>
    );

    assert.dom(".event-image").hasClass("--letterboxed");
    assert.strictEqual(
      document
        .querySelector(".event-image")
        .style.getPropertyValue("--event-image-color"),
      "",
      "no color is applied"
    );
  });

  test("keeps the banner crop when the image size is unknown", async function (assert) {
    const imageUpload = { url: "/uploads/default/original/1X/event.jpeg" };

    await render(
      <template>
        <Image
          @imageUpload={{imageUpload}}
          @linkToPost={{true}}
          @postUrl="/t/1"
        />
      </template>
    );

    assert
      .dom(".event-image")
      .doesNotHaveClass("--side")
      .doesNotHaveClass("--letterboxed");
  });
});
