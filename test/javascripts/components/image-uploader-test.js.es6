import componentTest from "helpers/component-test";
moduleForComponent("image-uploader", { integration: true });

componentTest("with image", {
  template: "{{image-uploader imageUrl='/some/upload.png'}}",

  async test(assert) {
    assert.equal(
      this.$(".d-icon-far-image").length,
      1,
      "it displays the upload icon"
    );

    assert.equal(
      this.$(".d-icon-far-trash-alt").length,
      1,
      "it displays the trash icon"
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
      this.$(".d-icon-far-image").length,
      1,
      "it displays the upload icon"
    );

    assert.equal(
      this.$(".d-icon-far-trash-alt").length,
      0,
      "it does not display trash icon"
    );

    assert.equal(
      this.$(".image-uploader-lightbox-btn").length,
      0,
      "it does not display the button to open image lightbox"
    );
  }
});
