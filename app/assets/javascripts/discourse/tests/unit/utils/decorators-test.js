import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import Component from "@ember/component";
import { clearRender, render } from "@ember/test-helpers";
import discourseComputed, {
  afterRender,
} from "discourse-common/utils/decorators";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

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

const EmberObjectComponent = Component.extend({
  name: "",
  layout: hbs`<span class="ember-object-component">{{this.text}}</span>`,

  @discourseComputed("name")
  text(name) {
    return `hello, ${name}`;
  },
});

class NativeComponent extends Component {
  name = "";
  layout = hbs`<span class="native-component">{{this.text}}</span>`;

  @discourseComputed("name")
  text(name) {
    return `hello, ${name}`;
  }
}

module("Unit | Utils | decorators", function (hooks) {
  setupRenderingTest(hooks);

  test("afterRender", async function (assert) {
    this.registry.register("component:foo-component", fooComponent);
    this.set("baz", 0);

    await render(hbs`{{foo-component baz=baz}}`);

    assert.ok(exists(document.querySelector(".foo-component")));
    assert.strictEqual(this.baz, 1);

    await clearRender();

    assert.ok(!exists(document.querySelector(".foo-component")));
    assert.strictEqual(this.baz, 1);
  });

  test("discourseComputed works in EmberObject classes", async function (assert) {
    this.registry.register(
      "component:ember-object-component",
      EmberObjectComponent
    );

    this.set("name", "Jarek");
    await render(hbs`<EmberObjectComponent @name={{this.name}} />`);

    assert.strictEqual(
      document.querySelector(".ember-object-component").textContent,
      "hello, Jarek"
    );

    this.set("name", "Joffrey");
    assert.strictEqual(
      document.querySelector(".ember-object-component").textContent,
      "hello, Joffrey",
      "rerenders the component when arguments change"
    );
  });

  test("discourseComputed works in native classes", async function (assert) {
    this.registry.register("component:native-component", NativeComponent);

    this.set("name", "Jarek");
    await render(hbs`<NativeComponent @name={{this.name}} />`);

    assert.strictEqual(
      document.querySelector(".native-component").textContent,
      "hello, Jarek"
    );

    this.set("name", "Joffrey");
    assert.strictEqual(
      document.querySelector(".native-component").textContent,
      "hello, Joffrey",
      "rerenders the component when arguments change"
    );
  });
});
