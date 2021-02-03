import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | d-button", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("icon only button", {
    template: hbs`{{d-button icon="plus" tabindex="3"}}`,

    test(assert) {
      assert.ok(
        queryAll("button.btn.btn-icon.no-text").length,
        "it has all the classes"
      );
      assert.ok(
        queryAll("button .d-icon.d-icon-plus").length,
        "it has the icon"
      );
      assert.equal(
        queryAll("button").attr("tabindex"),
        "3",
        "it has the tabindex"
      );
    },
  });

  componentTest("icon and text button", {
    template: hbs`{{d-button icon="plus" label="topic.create"}}`,

    test(assert) {
      assert.ok(
        queryAll("button.btn.btn-icon-text").length,
        "it has all the classes"
      );
      assert.ok(
        queryAll("button .d-icon.d-icon-plus").length,
        "it has the icon"
      );
      assert.ok(
        queryAll("button span.d-button-label").length,
        "it has the label"
      );
    },
  });

  componentTest("text only button", {
    template: hbs`{{d-button label="topic.create"}}`,

    test(assert) {
      assert.ok(
        queryAll("button.btn.btn-text").length,
        "it has all the classes"
      );
      assert.ok(
        queryAll("button span.d-button-label").length,
        "it has the label"
      );
    },
  });

  componentTest("form attribute", {
    template: hbs`{{d-button form="login-form"}}`,

    test(assert) {
      assert.ok(exists("button[form=login-form]"), "it has the form attribute");
    },
  });

  componentTest("link-styled button", {
    template: hbs`{{d-button display="link"}}`,

    test(assert) {
      assert.ok(
        queryAll("button.btn-link:not(.btn)").length,
        "it has the right classes"
      );
    },
  });

  componentTest("isLoading button", {
    template: hbs`{{d-button isLoading=isLoading}}`,

    beforeEach() {
      this.set("isLoading", true);
    },

    test(assert) {
      assert.ok(
        queryAll("button.is-loading .loading-icon").length,
        "it has a spinner showing"
      );
      assert.ok(
        queryAll("button[disabled]").length,
        "while loading the button is disabled"
      );

      this.set("isLoading", false);

      assert.notOk(
        queryAll("button .loading-icon").length,
        "it doesn't have a spinner showing"
      );
      assert.ok(
        queryAll("button:not([disabled])").length,
        "while not loading the button is enabled"
      );
    },
  });

  componentTest("disabled button", {
    template: hbs`{{d-button disabled=disabled}}`,

    beforeEach() {
      this.set("disabled", true);
    },

    test(assert) {
      assert.ok(queryAll("button[disabled]").length, "the button is disabled");

      this.set("disabled", false);

      assert.ok(
        queryAll("button:not([disabled])").length,
        "the button is enabled"
      );
    },
  });

  componentTest("aria-label", {
    template: hbs`{{d-button ariaLabel=ariaLabel translatedAriaLabel=translatedAriaLabel}}`,

    beforeEach() {
      I18n.translations[I18n.locale].js.test = { fooAriaLabel: "foo" };
    },

    test(assert) {
      this.set("ariaLabel", "test.fooAriaLabel");

      assert.equal(
        queryAll("button")[0].getAttribute("aria-label"),
        I18n.t("test.fooAriaLabel")
      );

      this.setProperties({
        ariaLabel: null,
        translatedAriaLabel: "bar",
      });

      assert.equal(queryAll("button")[0].getAttribute("aria-label"), "bar");
    },
  });

  componentTest("title", {
    template: hbs`{{d-button title=title translatedTitle=translatedTitle}}`,

    beforeEach() {
      I18n.translations[I18n.locale].js.test = { fooTitle: "foo" };
    },

    test(assert) {
      this.set("title", "test.fooTitle");
      assert.equal(
        queryAll("button")[0].getAttribute("title"),
        I18n.t("test.fooTitle")
      );

      this.setProperties({
        title: null,
        translatedTitle: "bar",
      });

      assert.equal(queryAll("button")[0].getAttribute("title"), "bar");
    },
  });

  componentTest("label", {
    template: hbs`{{d-button label=label translatedLabel=translatedLabel}}`,

    beforeEach() {
      I18n.translations[I18n.locale].js.test = { fooLabel: "foo" };
    },

    test(assert) {
      this.set("label", "test.fooLabel");

      assert.equal(
        queryAll("button .d-button-label").text(),
        I18n.t("test.fooLabel")
      );

      this.setProperties({
        label: null,
        translatedLabel: "bar",
      });

      assert.equal(queryAll("button .d-button-label").text(), "bar");
    },
  });
});
