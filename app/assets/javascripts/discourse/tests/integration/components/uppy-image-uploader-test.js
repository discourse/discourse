import { click, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | uppy-image-uploader", function (hooks) {
  setupRenderingTest(hooks);

  test("with image", async function (assert) {
    await render(hbs`
      <UppyImageUploader @type="avatar" @id="uploader" @imageUrl="/images/avatar.png" @placeholderUrl="/not/used.png" />
    `);

    assert.dom(".d-icon-far-image").exists("displays the upload icon");
    assert.dom(".d-icon-trash-can").exists("displays the trash icon");

    assert
      .dom(".placeholder-overlay")
      .doesNotExist("it does not display the placeholder image");

    await click(".image-uploader-lightbox-btn");

    assert.strictEqual(
      document.querySelectorAll(".mfp-container").length,
      1,
      "it displays the image lightbox"
    );
  });

  test("without image", async function (assert) {
    await render(
      hbs`<UppyImageUploader @type="site_setting" @id="uploader" />`
    );

    assert.dom(".d-icon-far-image").exists("displays the upload icon");
    assert.dom(".d-icon-trash-can").doesNotExist("does not display trash icon");

    assert
      .dom(".image-uploader-lightbox-btn")
      .doesNotExist("it does not display the button to open image lightbox");
  });

  test("with placeholder", async function (assert) {
    await render(
      hbs`<UppyImageUploader @type="composer" @id="uploader" @placeholderUrl="/images/avatar.png" />`
    );

    assert.dom(".d-icon-far-image").exists("displays the upload icon");
    assert.dom(".d-icon-trash-can").doesNotExist("does not display trash icon");

    assert
      .dom(".image-uploader-lightbox-btn")
      .doesNotExist("it does not display the button to open image lightbox");

    assert.dom(".placeholder-overlay").exists("displays the placeholder image");
  });

  test("when dragging image", async function (assert) {
    await render(
      hbs`
      <UppyImageUploader @type="composer" @id="uploader1" />
      <UppyImageUploader @type="composer" @id="uploader2" />
      `
    );

    const dropImage = (target) => {
      target = document.querySelector(target);
      const dataTransfer = new DataTransfer();
      const file = new File(["dummy content"], "test-image.png", {
        type: "image/png",
      });
      dataTransfer.items.add(file);
      const dragEnterEvent = new DragEvent("dragenter", { dataTransfer });
      target.dispatchEvent(dragEnterEvent);
      const dragOverEvent = new DragEvent("dragover", { dataTransfer });
      target.dispatchEvent(dragOverEvent);

      return () => {
        const dragLeaveEvent = new DragEvent("dragleave", { dataTransfer });
        target.dispatchEvent(dragLeaveEvent);
      };
    };

    const leave1 = dropImage("#uploader1 .uploaded-image-preview");

    assert
      .dom("#uploader1 .uploaded-image-preview")
      .hasClass("uppy-is-drag-over");
    assert
      .dom("#uploader2 .uploaded-image-preview")
      .hasNoClass("uppy-is-drag-over");

    leave1();

    dropImage("#uploader2 .uploaded-image-preview");

    assert
      .dom("#uploader2 .uploaded-image-preview")
      .hasClass("uppy-is-drag-over");
    assert
      .dom("#uploader1 .uploaded-image-preview")
      .hasNoClass("uppy-is-drag-over");
  });
});
