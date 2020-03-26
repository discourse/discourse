import componentTest from "helpers/component-test";

moduleForComponent("text-field", { integration: true });

componentTest("renders correctly with no properties set", {
  template: `{{text-field}}`,

  test(assert) {
    assert.ok(find("input[type=text]").length);
  }
});

componentTest("support a placeholder", {
  template: `{{text-field placeholderKey="placeholder.i18n.key"}}`,

  beforeEach() {
    sandbox.stub(I18n, "t").returnsArg(0);
  },

  test(assert) {
    assert.ok(find("input[type=text]").length);
    assert.equal(find("input").prop("placeholder"), "placeholder.i18n.key");
  }
});

componentTest("sets the dir attribute to ltr for Hebrew text", {
  template: `{{text-field value='זהו שם עברי עם מקום עברי'}}`,
  beforeEach() {
    this.siteSettings.support_mixed_text_direction = true;
  },

  test(assert) {
    assert.equal(find("input").attr("dir"), "rtl");
  }
});

componentTest("sets the dir attribute to ltr for English text", {
  template: `{{text-field value='This is a ltr title'}}`,
  beforeEach() {
    this.siteSettings.support_mixed_text_direction = true;
  },

  test(assert) {
    assert.equal(find("input").attr("dir"), "ltr");
  }
});
