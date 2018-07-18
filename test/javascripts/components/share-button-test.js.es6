import componentTest from "helpers/component-test";
moduleForComponent("share-button", { integration: true });

componentTest("share button", {
  template: '{{share-button url="https://eviltrout.com"}}',

  test(assert) {
    assert.ok(this.$(`button.share`).length, "it has all the classes");

    assert.ok(
      this.$(`button[data-share-url="https://eviltrout.com"]`).length,
      "it has the data attribute for sharing"
    );
  }
});
