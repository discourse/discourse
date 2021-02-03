import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { click } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | image-uploader", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("with image", {
    template: hbs`
      {{image-uploader imageUrl='/images/avatar.png' placeholderUrl='/not/used.png'}}
    `,

    async test(assert) {
      assert.equal(
        queryAll(".d-icon-far-image").length,
        1,
        "it displays the upload icon"
      );

      assert.equal(
        queryAll(".d-icon-far-trash-alt").length,
        1,
        "it displays the trash icon"
      );

      assert.equal(
        queryAll(".placeholder-overlay").length,
        0,
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
    template: hbs`{{image-uploader}}`,

    test(assert) {
      assert.equal(
        queryAll(".d-icon-far-image").length,
        1,
        "it displays the upload icon"
      );

      assert.equal(
        queryAll(".d-icon-far-trash-alt").length,
        0,
        "it does not display trash icon"
      );

      assert.equal(
        queryAll(".image-uploader-lightbox-btn").length,
        0,
        "it does not display the button to open image lightbox"
      );
    },
  });

  componentTest("with placeholder", {
    template: hbs`{{image-uploader placeholderUrl='/images/avatar.png'}}`,

    test(assert) {
      assert.equal(
        queryAll(".d-icon-far-image").length,
        1,
        "it displays the upload icon"
      );

      assert.equal(
        queryAll(".d-icon-far-trash-alt").length,
        0,
        "it does not display trash icon"
      );

      assert.equal(
        queryAll(".image-uploader-lightbox-btn").length,
        0,
        "it does not display the button to open image lightbox"
      );

      assert.equal(
        queryAll(".placeholder-overlay").length,
        1,
        "it displays the placeholder image"
      );
    },
  });
});
