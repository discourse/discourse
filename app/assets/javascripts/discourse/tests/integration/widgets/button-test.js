import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  exists,
  query,
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
        exists("button.btn.btn-icon.no-text"),
        "it has all the classes"
      );
      assert.ok(exists("button .d-icon.d-icon-far-smile"), "it has the icon");
    },
  });

  componentTest("icon and text button", {
    template: hbs`{{mount-widget widget="button" args=args}}`,

    beforeEach() {
      this.set("args", { icon: "plus", label: "topic.create" });
    },

    test(assert) {
      assert.ok(exists("button.btn.btn-icon-text"), "it has all the classes");
      assert.ok(exists("button .d-icon.d-icon-plus"), "it has the icon");
      assert.ok(exists("button span.d-button-label"), "it has the label");
    },
  });

  componentTest("text only button", {
    template: hbs`{{mount-widget widget="button" args=args}}`,

    beforeEach() {
      this.set("args", { label: "topic.create" });
    },

    test(assert) {
      assert.ok(exists("button.btn.btn-text"), "it has all the classes");
      assert.ok(exists("button span.d-button-label"), "it has the label");
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
