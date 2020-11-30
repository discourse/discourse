import { exists } from "discourse/tests/helpers/qunit-helpers";
import { afterRender } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import componentTest from "discourse/tests/helpers/component-test";
import { moduleForComponent } from "ember-qunit";

const fooComponent = Component.extend({
  layoutName: "foo-component",

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

moduleForComponent("utils:decorators", { integration: true });

componentTest("afterRender", {
  template: "{{foo-component baz=baz}}",

  beforeEach() {
    this.registry.register("component:foo-component", fooComponent);
    this.set("baz", 0);
  },

  test(assert) {
    assert.ok(exists(document.querySelector(".foo-component")));
    assert.equal(this.baz, 1);

    this.clearRender();

    assert.ok(!exists(document.querySelector(".foo-component")));
    assert.equal(this.baz, 1);
  },
});
