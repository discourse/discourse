import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | Widget | button", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("icon only button", {
    template: hbs`{{mount-widget widget="button" args=args}}`,

    beforeEach() {
      this.set("args", { icon: "far-smile" });
    },

    test(assert) {
      assert.ok(
        queryAll("button.btn.btn-icon.no-text").length,
        "it has all the classes"
      );
      assert.ok(
        queryAll("button .d-icon.d-icon-far-smile").length,
        "it has the icon"
      );
    },
  });

  componentTest("icon and text button", {
    template: hbs`{{mount-widget widget="button" args=args}}`,

    beforeEach() {
      this.set("args", { icon: "plus", label: "topic.create" });
    },

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
    template: hbs`{{mount-widget widget="button" args=args}}`,

    beforeEach() {
      this.set("args", { label: "topic.create" });
    },

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

  componentTest("translatedLabel", {
    template: hbs`{{mount-widget widget="button" args=args}}`,

    beforeEach() {
      this.set("args", { translatedLabel: "foo bar" });
    },

    test(assert) {
      assert.equal(query("button span.d-button-label").innerText, "foo bar");
    },
  });

  componentTest("translatedTitle", {
    template: hbs`{{mount-widget widget="button" args=args}}`,

    beforeEach() {
      this.set("args", { label: "topic.create", translatedTitle: "foo bar" });
    },

    test(assert) {
      assert.equal(query("button").title, "foo bar");
      assert.equal(query("button").getAttribute("aria-label"), "foo bar");
    },
  });
});
