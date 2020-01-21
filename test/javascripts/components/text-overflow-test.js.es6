import componentTest from "helpers/component-test";

moduleForComponent("text-overflow", { integration: true });

componentTest("default", {
  template: `
    <style>
      .overflow {
        max-height: 40px;
        overflow: hidden;
        width: 500px;
      }
    </style>

    <div>{{text-overflow class='overflow' text=text}}</div>`,

  beforeEach() {
    this.set(
      "text",
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit.\nFusce convallis faucibus tortor quis vestibulum.<br>\nPhasellus pharetra dolor eget imperdiet tempor.<br>\nQuisque hendrerit magna id consectetur rutrum.<br>\nNulla vel tortor leo.<br>\nFusce ullamcorper lacus quis sodales ornare.<br>"
    );
  },

  test(assert) {
    const text = find(".overflow")
      .text()
      .trim();

    assert.ok(text.startsWith("Lorem ipsum dolor sit amet"));
    assert.ok(text.endsWith("..."));
  }
});
