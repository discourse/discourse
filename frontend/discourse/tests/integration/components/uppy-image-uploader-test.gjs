import { click, render, triggerEvent, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | UppyImageUploader", function (hooks) {
  setupRenderingTest(hooks);

  test("with image", async function (assert) {
    await render(
      <template>
        <UppyImageUploader
          @id="uploader"
          @imageUrl="/images/avatar.png"
          @placeholderUrl="/not/used.png"
          @type="avatar"
        />
      </template>
    );

    assert.dom(".d-icon-upload").exists("displays the upload icon");
    assert.dom(".d-icon-trash-can").exists("displays the trash icon");

    assert
      .dom(".placeholder-overlay")
      .doesNotExist("does not display the placeholder image");

    await click(".image-uploader-lightbox-btn");
    await waitFor(".pswp--open");

    assert.dom(".pswp").exists("displays the image lightbox");
  });

  test("without image", async function (assert) {
    await render(
      <template>
        <UppyImageUploader @id="uploader" @type="site_setting" />
      </template>
    );

    assert.dom(".d-icon-upload").exists("displays the upload icon");
    assert.dom(".d-icon-trash-can").doesNotExist("does not display trash icon");

    assert
      .dom(".image-uploader-lightbox-btn")
      .doesNotExist("does not display the button to open image lightbox");
  });

  test("with placeholder", async function (assert) {
    await render(
      <template>
        <UppyImageUploader
          @id="uploader"
          @placeholderUrl="/images/avatar.png"
          @type="composer"
        />
      </template>
    );

    assert.dom(".d-icon-upload").exists("displays the upload icon");
    assert.dom(".d-icon-trash-can").doesNotExist("does not display trash icon");

    assert
      .dom(".image-uploader-lightbox-btn")
      .doesNotExist("does not display the button to open image lightbox");

    assert.dom(".placeholder-overlay").exists("displays the placeholder image");
  });

  test("when dragging image", async function (assert) {
    await render(
      <template>
        <UppyImageUploader @id="uploader1" @type="composer" />
        <UppyImageUploader @id="uploader2" @type="composer" />
      </template>
    );

    const dropImage = async (target) => {
      const dataTransfer = new DataTransfer();
      const file = new File(["dummy content"], "test-image.png", {
        type: "image/png",
      });
      dataTransfer.items.add(file);

      await triggerEvent(target, "dragenter", { dataTransfer });
      await triggerEvent(target, "dragover", { dataTransfer });

      return async () => {
        await triggerEvent(target, "dragleave", { dataTransfer });
      };
    };

    const leave1 = await dropImage("#uploader1 .file-uploader__preview");

    assert
      .dom("#uploader1 .file-uploader__preview")
      .hasClass("uppy-is-drag-over");
    assert
      .dom("#uploader2 .file-uploader__preview")
      .hasNoClass("uppy-is-drag-over");

    await leave1();

    await dropImage("#uploader2 .file-uploader__preview");

    assert
      .dom("#uploader2 .file-uploader__preview")
      .hasClass("uppy-is-drag-over");
    assert
      .dom("#uploader1 .file-uploader__preview")
      .hasNoClass("uppy-is-drag-over");
  });

  test("accepts only images when allowVideo is unset", async function (assert) {
    await render(
      <template>
        <UppyImageUploader @id="uploader-without-video" @type="composer" />
      </template>
    );

    assert
      .dom("#uploader-without-video__input")
      .hasAttribute(
        "accept",
        "image/*",
        "only accepts images when allowVideo is false"
      );
  });

  test("accepts images and videos when allowVideo is true", async function (assert) {
    await render(
      <template>
        <UppyImageUploader
          @allowVideo={{true}}
          @id="uploader-with-video"
          @type="composer"
        />
      </template>
    );

    assert
      .dom("#uploader-with-video__input")
      .hasAttribute(
        "accept",
        "image/*,video/*",
        "accepts videos when allowVideo is true"
      );
  });

  test("with video and allowVideo=true", async function (assert) {
    await render(
      <template>
        <UppyImageUploader
          @allowVideo={{true}}
          @id="uploader"
          @imageUrl="/images/video.mp4"
          @type="composer"
        />
      </template>
    );

    assert.dom("video").exists("displays the video element");
    assert.dom(".meta").exists("displays the file metadata");
    assert
      .dom(".expand-overlay")
      .doesNotExist("does not display the lightbox button");
  });
});
