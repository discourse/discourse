import Component from "@ember/component";
import { afterRender } from "discourse-common/utils/decorators";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, exists } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

const fooComponent = Component.extend({
  classNames: ["foo-component"],

  baz: null,

  didInsertElement() {
    this._super(...arguments);

    this.setBaz(1);
  },

  willDestroyElement() {
    this._super(...arguments);

    this.setBaz(2);
  },

  @afterRender
  setBaz(baz) {
    this.set("baz", baz);
  },
});

discourseModule("utils:decorators", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("afterRender", {
    template: hbs`{{foo-component baz=baz}}`,

    beforeEach() {
      this.registry.register("component:foo-component", fooComponent);
      this.set("baz", 0);
    },

    async test(assert) {
      assert.ok(exists(document.querySelector(".foo-component")));
      assert.strictEqual(this.baz, 1);

      await this.clearRender();

      assert.ok(!exists(document.querySelector(".foo-component")));
      assert.strictEqual(this.baz, 1);
    },
  });
});
