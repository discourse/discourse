import componentTest from "helpers/component-test";

moduleForComponent("list-setting", { integration: true });

componentTest("default", {
  template: "{{list-setting settingValue=settingValue choices=choices}}",

  beforeEach() {
    this.set("settingValue", "bold|italic");
    this.set("choices", ["bold", "italic", "underline"]);
  },

  test(assert) {
    assert.equal(
      selectKit()
        .header()
        .title(),
      "bold,italic"
    );
    assert.equal(
      selectKit()
        .header()
        .value(),
      "bold,italic"
    );
  }
});

componentTest("with empty string as value", {
  template: "{{list-setting settingValue=settingValue}}",

  beforeEach() {
    this.set("settingValue", "");
  },

  test(assert) {
    assert.equal(
      selectKit()
        .header()
        .value(),
      ""
    );
  }
});

componentTest("with only setting value", {
  template: "{{list-setting settingValue=settingValue}}",

  beforeEach() {
    this.set("settingValue", "bold|italic");
  },

  test(assert) {
    assert.equal(
      selectKit()
        .header()
        .value(),
      "bold,italic"
    );
  }
});

componentTest("interactions", {
  template: "{{list-setting settingValue=settingValue choices=choices}}",

  beforeEach() {
    this.set("settingValue", "bold|italic");
    this.set("choices", ["bold", "italic", "underline"]);
  },

  async test(assert) {
    const listSetting = selectKit();

    await listSetting.expand();
    await listSetting.selectRowByValue("underline");

    assert.equal(listSetting.header().value(), "bold,italic,underline");

    await listSetting.expand();
    await listSetting.fillInFilter("strike");

    assert.equal(listSetting.highlightedRow().value(), "strike");

    await listSetting.keyboard("enter");

    assert.equal(listSetting.header().value(), "bold,italic,underline,strike");

    await listSetting.keyboard("backspace");
    await listSetting.keyboard("backspace");

    assert.equal(listSetting.header().value(), "bold,italic,underline");
  }
});
