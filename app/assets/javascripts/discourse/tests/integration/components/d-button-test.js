import { exists } from "discourse/tests/helpers/qunit-helpers";
import { moduleForComponent } from "ember-qunit";
import I18n from "I18n";
import componentTest from "discourse/tests/helpers/component-test";
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
  },
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
  },
});

componentTest("text only button", {
  template: '{{d-button label="topic.create"}}',

  test(assert) {
    assert.ok(find("button.btn.btn-text").length, "it has all the classes");
    assert.ok(find("button span.d-button-label").length, "it has the label");
  },
});

componentTest("form attribute", {
  template: '{{d-button form="login-form"}}',

  test(assert) {
    assert.ok(exists("button[form=login-form]"), "it has the form attribute");
  },
});

componentTest("link-styled button", {
  template: '{{d-button display="link"}}',

  test(assert) {
    assert.ok(
      find("button.btn-link:not(.btn)").length,
      "it has the right classes"
    );
  },
});

componentTest("isLoading button", {
  template: "{{d-button isLoading=isLoading}}",

  beforeEach() {
    this.set("isLoading", true);
  },

  test(assert) {
    assert.ok(
      find("button.is-loading .loading-icon").length,
      "it has a spinner showing"
    );
    assert.ok(
      find("button[disabled]").length,
      "while loading the button is disabled"
    );

    this.set("isLoading", false);

    assert.notOk(
      find("button .loading-icon").length,
      "it doesn't have a spinner showing"
    );
    assert.ok(
      find("button:not([disabled])").length,
      "while not loading the button is enabled"
    );
  },
});

componentTest("disabled button", {
  template: "{{d-button disabled=disabled}}",

  beforeEach() {
    this.set("disabled", true);
  },

  test(assert) {
    assert.ok(find("button[disabled]").length, "the button is disabled");

    this.set("disabled", false);

    assert.ok(find("button:not([disabled])").length, "the button is enabled");
  },
});

componentTest("aria-label", {
  template:
    "{{d-button ariaLabel=ariaLabel translatedAriaLabel=translatedAriaLabel}}",

  beforeEach() {
    I18n.translations[I18n.locale].js.test = { fooAriaLabel: "foo" };
  },

  test(assert) {
    this.set("ariaLabel", "test.fooAriaLabel");

    assert.equal(
      find("button")[0].getAttribute("aria-label"),
      I18n.t("test.fooAriaLabel")
    );

    this.setProperties({
      ariaLabel: null,
      translatedAriaLabel: "bar",
    });

    assert.equal(find("button")[0].getAttribute("aria-label"), "bar");
  },
});

componentTest("title", {
  template: "{{d-button title=title translatedTitle=translatedTitle}}",

  beforeEach() {
    I18n.translations[I18n.locale].js.test = { fooTitle: "foo" };
  },

  test(assert) {
    this.set("title", "test.fooTitle");
    assert.equal(
      find("button")[0].getAttribute("title"),
      I18n.t("test.fooTitle")
    );

    this.setProperties({
      title: null,
      translatedTitle: "bar",
    });

    assert.equal(find("button")[0].getAttribute("title"), "bar");
  },
});

componentTest("label", {
  template: "{{d-button label=label translatedLabel=translatedLabel}}",

  beforeEach() {
    I18n.translations[I18n.locale].js.test = { fooLabel: "foo" };
  },

  test(assert) {
    this.set("label", "test.fooLabel");

    assert.equal(
      find("button .d-button-label").text(),
      I18n.t("test.fooLabel")
    );

    this.setProperties({
      label: null,
      translatedLabel: "bar",
    });

    assert.equal(find("button .d-button-label").text(), "bar");
  },
});
