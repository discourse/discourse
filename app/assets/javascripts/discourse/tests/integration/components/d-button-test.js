import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  exists,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { triggerKeyEvent } from "@ember/test-helpers";
import I18n from "I18n";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | d-button", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("icon only button", {
    template: hbs`{{d-button icon="plus" tabindex="3"}}`,

    test(assert) {
      assert.ok(
        exists("button.btn.btn-icon.no-text"),
        "it has all the classes"
      );
      assert.ok(exists("button .d-icon.d-icon-plus"), "it has the icon");
      assert.strictEqual(
        queryAll("button").attr("tabindex"),
        "3",
        "it has the tabindex"
      );
    },
  });

  componentTest("icon and text button", {
    template: hbs`{{d-button icon="plus" label="topic.create"}}`,

    test(assert) {
      assert.ok(exists("button.btn.btn-icon-text"), "it has all the classes");
      assert.ok(exists("button .d-icon.d-icon-plus"), "it has the icon");
      assert.ok(exists("button span.d-button-label"), "it has the label");
    },
  });

  componentTest("text only button", {
    template: hbs`{{d-button label="topic.create"}}`,

    test(assert) {
      assert.ok(exists("button.btn.btn-text"), "it has all the classes");
      assert.ok(exists("button span.d-button-label"), "it has the label");
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
        exists("button.btn-link:not(.btn)"),
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
        exists("button.is-loading .loading-icon"),
        "it has a spinner showing"
      );
      assert.ok(
        exists("button[disabled]"),
        "while loading the button is disabled"
      );

      this.set("isLoading", false);

      assert.notOk(
        exists("button .loading-icon"),
        "it doesn't have a spinner showing"
      );
      assert.ok(
        exists("button:not([disabled])"),
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
      assert.ok(exists("button[disabled]"), "the button is disabled");

      this.set("disabled", false);

      assert.ok(exists("button:not([disabled])"), "the button is enabled");
    },
  });

  componentTest("aria-label", {
    template: hbs`{{d-button ariaLabel=ariaLabel translatedAriaLabel=translatedAriaLabel}}`,

    beforeEach() {
      I18n.translations[I18n.locale].js.test = { fooAriaLabel: "foo" };
    },

    test(assert) {
      this.set("ariaLabel", "test.fooAriaLabel");

      assert.strictEqual(
        query("button").getAttribute("aria-label"),
        I18n.t("test.fooAriaLabel")
      );

      this.setProperties({
        ariaLabel: null,
        translatedAriaLabel: "bar",
      });

      assert.strictEqual(query("button").getAttribute("aria-label"), "bar");
    },
  });

  componentTest("title", {
    template: hbs`{{d-button title=title translatedTitle=translatedTitle}}`,

    beforeEach() {
      I18n.translations[I18n.locale].js.test = { fooTitle: "foo" };
    },

    test(assert) {
      this.set("title", "test.fooTitle");
      assert.strictEqual(
        query("button").getAttribute("title"),
        I18n.t("test.fooTitle")
      );

      this.setProperties({
        title: null,
        translatedTitle: "bar",
      });

      assert.strictEqual(query("button").getAttribute("title"), "bar");
    },
  });

  componentTest("label", {
    template: hbs`{{d-button label=label translatedLabel=translatedLabel}}`,

    beforeEach() {
      I18n.translations[I18n.locale].js.test = { fooLabel: "foo" };
    },

    test(assert) {
      this.set("label", "test.fooLabel");

      assert.strictEqual(
        queryAll("button .d-button-label").text(),
        I18n.t("test.fooLabel")
      );

      this.setProperties({
        label: null,
        translatedLabel: "bar",
      });

      assert.strictEqual(queryAll("button .d-button-label").text(), "bar");
    },
  });

  componentTest("aria-expanded", {
    template: hbs`{{d-button ariaExpanded=ariaExpanded}}`,

    test(assert) {
      assert.strictEqual(query("button").getAttribute("aria-expanded"), null);

      this.set("ariaExpanded", true);
      assert.strictEqual(query("button").getAttribute("aria-expanded"), "true");

      this.set("ariaExpanded", false);
      assert.strictEqual(
        query("button").getAttribute("aria-expanded"),
        "false"
      );

      this.set("ariaExpanded", "false");
      assert.strictEqual(query("button").getAttribute("aria-expanded"), null);

      this.set("ariaExpanded", "true");
      assert.strictEqual(query("button").getAttribute("aria-expanded"), null);
    },
  });

  componentTest("aria-controls", {
    template: hbs`{{d-button ariaControls=ariaControls}}`,

    test(assert) {
      this.set("ariaControls", "foo-bar");
      assert.strictEqual(
        query("button").getAttribute("aria-controls"),
        "foo-bar"
      );
    },
  });

  componentTest("onKeyDown callback", {
    template: hbs`{{d-button action=action onKeyDown=onKeyDown}}`,

    beforeEach() {
      this.set("foo", null);
      this.set("onKeyDown", () => {
        this.set("foo", "bar");
      });
      this.set("action", () => {
        this.set("foo", "baz");
      });
    },

    async test(assert) {
      await triggerKeyEvent(".btn", "keydown", 32);

      assert.strictEqual(this.foo, "bar");

      await triggerKeyEvent(".btn", "keydown", 13);

      assert.strictEqual(this.foo, "bar");
    },
  });

  componentTest("press Enter", {
    template: hbs`{{d-button action=action}}`,

    beforeEach() {
      this.set("foo", null);
      this.set("action", () => {
        this.set("foo", "bar");
      });
    },

    async test(assert) {
      await triggerKeyEvent(".btn", "keydown", 32);

      assert.strictEqual(this.foo, null);

      await triggerKeyEvent(".btn", "keydown", 13);

      assert.strictEqual(this.foo, "bar");
    },
  });
});
