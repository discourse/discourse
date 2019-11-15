import componentTest from "helpers/component-test";
moduleForComponent("d-button", { integration: true });

componentTest("icon only button", {
  template: '{{d-button icon="plus" tabindex="3"}}',

  test(assert) {
    assert.ok(
      find("button.btn.btn-icon.no-text").length,
      "it has all the classes"
    );
    assert.ok(find("button .d-icon.d-icon-plus").length, "it has the icon");
    assert.equal(find("button").attr("tabindex"), "3", "it has the tabindex");
  }
});

componentTest("icon and text button", {
  template: '{{d-button icon="plus" label="topic.create"}}',

  test(assert) {
    assert.ok(
      find("button.btn.btn-icon-text").length,
      "it has all the classes"
    );
    assert.ok(find("button .d-icon.d-icon-plus").length, "it has the icon");
    assert.ok(find("button span.d-button-label").length, "it has the label");
  }
});

componentTest("text only button", {
  template: '{{d-button label="topic.create"}}',

  test(assert) {
    assert.ok(find("button.btn.btn-text").length, "it has all the classes");
    assert.ok(find("button span.d-button-label").length, "it has the label");
  }
});

componentTest("form attribute", {
  template: '{{d-button form="login-form"}}',

  test(assert) {
    assert.ok(exists("button[form=login-form]"), "it has the form attribute");
  }
});

componentTest("link-styled button", {
  template: '{{d-button display="link"}}',

  test(assert) {
    assert.ok(
      find("button.btn-link:not(.btn)").length,
      "it has the right classes"
    );
  }
});
