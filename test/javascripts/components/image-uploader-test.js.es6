import componentTest from "helpers/component-test";
moduleForComponent("image-uploader", { integration: true });

componentTest("without image", {
  template: "{{image-uploader}}",

  test(assert) {
    assert.equal(
      this.$(".d-icon-trash-o").length,
      0,
      "it does not display trash icon"
    );
  }
});
