import { queryAll } from "discourse/tests/helpers/qunit-helpers";
import { moduleForComponent } from "ember-qunit";
import componentTest from "discourse/tests/helpers/component-test";
import { click } from "@ember/test-helpers";

moduleForComponent("image-uploader", { integration: true });

componentTest("with image", {
  template:
    "{{image-uploader imageUrl='/images/avatar.png' placeholderUrl='/not/used.png'}}",

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
  template: "{{image-uploader}}",

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
  template: "{{image-uploader placeholderUrl='/images/avatar.png'}}",

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
