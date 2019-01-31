import componentTest from "helpers/component-test";
moduleForComponent("image-uploader", { integration: true });

componentTest("with image", {
  template: "{{image-uploader imageUrl='/some/upload.png'}}",

  test(assert) {
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
  }
});
