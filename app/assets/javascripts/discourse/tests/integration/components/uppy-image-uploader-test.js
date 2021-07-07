import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  count,
  discourseModule,
  exists,
} from "discourse/tests/helpers/qunit-helpers";
import { click } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule(
  "Integration | Component | uppy-image-uploader",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("with image", {
      template: hbs`
      {{uppy-image-uploader imageUrl='/images/avatar.png' placeholderUrl='/not/used.png'}}
    `,

      async test(assert) {
        assert.equal(
          count(".d-icon-far-image"),
          1,
          "it displays the upload icon"
        );

        assert.equal(
          count(".d-icon-far-trash-alt"),
          1,
          "it displays the trash icon"
        );

        assert.ok(
          !exists(".placeholder-overlay"),
          "it does not display the placeholder image"
        );

        await click(".image-uploader-lightbox-btn");

        assert.equal(
          $(".mfp-container").length,
          1,
          "it displays the image lightbox"
        );
      },
    });

    componentTest("without image", {
      template: hbs`{{uppy-image-uploader}}`,

      test(assert) {
        assert.equal(
          count(".d-icon-far-image"),
          1,
          "it displays the upload icon"
        );

        assert.ok(
          !exists(".d-icon-far-trash-alt"),
          "it does not display trash icon"
        );

        assert.ok(
          !exists(".image-uploader-lightbox-btn"),
          "it does not display the button to open image lightbox"
        );
      },
    });

    componentTest("with placeholder", {
      template: hbs`{{uppy-image-uploader placeholderUrl='/images/avatar.png'}}`,

      test(assert) {
        assert.equal(
          count(".d-icon-far-image"),
          1,
          "it displays the upload icon"
        );

        assert.ok(
          !exists(".d-icon-far-trash-alt"),
          "it does not display trash icon"
        );

        assert.ok(
          !exists(".image-uploader-lightbox-btn"),
          "it does not display the button to open image lightbox"
        );

        assert.equal(
          count(".placeholder-overlay"),
          1,
          "it displays the placeholder image"
        );
      },
    });
  }
);
