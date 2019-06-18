import componentTest from "helpers/component-test";

moduleForComponent("share-button", { integration: true });

componentTest("share button", {
  template: '{{share-button url="https://eviltrout.com"}}',

  test(assert) {
    assert.ok(find(`button.share`).length, "it has all the classes");

    assert.ok(
      find('button[data-share-url="https://eviltrout.com"]').length,
      "it has the data attribute for sharing"
    );
  }
});
