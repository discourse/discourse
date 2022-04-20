import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | badge-button", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("disabled badge", {
    template: hbs`{{badge-button badge=badge}}`,

    beforeEach() {
      this.set("badge", { enabled: false });
    },

    async test(assert) {
      assert.ok(exists(".user-badge.disabled"));
    },
  });

  componentTest("enabled badge", {
    template: hbs`{{badge-button badge=badge}}`,

    beforeEach() {
      this.set("badge", { enabled: true });
    },

    async test(assert) {
      assert.notOk(exists(".user-badge.disabled"));
    },
  });

  componentTest("data-badge-name", {
    template: hbs`{{badge-button badge=badge}}`,

    beforeEach() {
      this.set("badge", { name: "foo" });
    },

    async test(assert) {
      assert.ok(exists('.user-badge[data-badge-name="foo"]'));
    },
  });

  componentTest("title", {
    template: hbs`{{badge-button badge=badge}}`,

    beforeEach() {
      this.set("badge", { description: "a <a href>good</a> run" });
    },

    async test(assert) {
      assert.equal(query(".user-badge").title, "a good run", "it strips html");
    },
  });

  componentTest("icon", {
    template: hbs`{{badge-button badge=badge}}`,

    beforeEach() {
      this.set("badge", { icon: "times" });
    },

    async test(assert) {
      assert.ok(exists(".d-icon.d-icon-times"));
    },
  });

  componentTest("accepts block", {
    template: hbs`{{#badge-button badge=badge}}<span class="test"></span>{{/badge-button}}`,

    beforeEach() {
      this.set("badge", {});
    },

    async test(assert) {
      assert.ok(exists(".test"));
    },
  });

  componentTest("badgeTypeClassName", {
    template: hbs`{{badge-button badge=badge}}`,

    beforeEach() {
      this.set("badge", { badgeTypeClassName: "foo" });
    },

    async test(assert) {
      assert.ok(exists(".user-badge.foo"));
    },
  });
});
