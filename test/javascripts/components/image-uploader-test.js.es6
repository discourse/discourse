import componentTest from "helpers/component-test";
moduleForComponent("image-uploader", { integration: true });

componentTest("with image", {
  template:
    "{{image-uploader imageUrl='/some/upload.png' placeholderUrl='/not/used.png'}}",

  async test(assert) {
    assert.equal(
      find(".d-icon-far-image").length,
      1,
      "it displays the upload icon"
    );

    assert.equal(
      find(".d-icon-far-trash-alt").length,
      1,
      "it displays the trash icon"
    );

    assert.equal(
      find(".placeholder-overlay").length,
      0,
      "it does not display the placeholder image"
    );

    await click(".image-uploader-lightbox-btn");

    assert.equal(
      $(".mfp-container").length,
      1,
      "it displays the image lightbox"
    );
  }
});

componentTest("without image", {
  template: "{{image-uploader}}",

  test(assert) {
    assert.equal(
      find(".d-icon-far-image").length,
      1,
      "it displays the upload icon"
    );

    assert.equal(
      find(".d-icon-far-trash-alt").length,
      0,
      "it does not display trash icon"
    );

    assert.equal(
      find(".image-uploader-lightbox-btn").length,
      0,
      "it does not display the button to open image lightbox"
    );
  }
});

componentTest("with placeholder", {
  template: "{{image-uploader placeholderUrl='/some/image.png'}}",

  test(assert) {
    assert.equal(
      find(".d-icon-far-image").length,
      1,
      "it displays the upload icon"
    );

    assert.equal(
      find(".d-icon-far-trash-alt").length,
      0,
      "it does not display trash icon"
    );

    assert.equal(
      find(".image-uploader-lightbox-btn").length,
      0,
      "it does not display the button to open image lightbox"
    );

    assert.equal(
      find(".placeholder-overlay").length,
      1,
      "it displays the placeholder image"
    );
  }
});
