import { click, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | uppy-image-uploader", function (hooks) {
  setupRenderingTest(hooks);

  test("with image", async function (assert) {
    await render(hbs`
      <UppyImageUploader @type="avatar" @id="test-uppy-image-uploader" @imageUrl="/images/avatar.png" @placeholderUrl="/not/used.png" />
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
      hbs`<UppyImageUploader @type="site_setting" @id="test-uppy-image-uploader" />`
    );

    assert.dom(".d-icon-far-image").exists("displays the upload icon");
    assert.dom(".d-icon-trash-can").doesNotExist("does not display trash icon");

    assert
      .dom(".image-uploader-lightbox-btn")
      .doesNotExist("it does not display the button to open image lightbox");
  });

  test("with placeholder", async function (assert) {
    await render(
      hbs`<UppyImageUploader @type="composer" @id="test-uppy-image-uploader" @placeholderUrl="/images/avatar.png" />`
    );

    assert.dom(".d-icon-far-image").exists("displays the upload icon");
    assert.dom(".d-icon-trash-can").doesNotExist("does not display trash icon");

    assert
      .dom(".image-uploader-lightbox-btn")
      .doesNotExist("it does not display the button to open image lightbox");

    assert.dom(".placeholder-overlay").exists("displays the placeholder image");
  });
});
