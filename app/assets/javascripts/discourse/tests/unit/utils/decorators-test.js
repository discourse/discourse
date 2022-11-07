import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import Component from "@ember/component";
import { clearRender, render, settled } from "@ember/test-helpers";
import discourseComputed, {
  afterRender,
  debounce,
  observes,
} from "discourse-common/utils/decorators";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import EmberObject from "@ember/object";

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

const TestStub = EmberObject.extend({
  counter: 0,
  otherCounter: 0,

  @debounce(50)
  increment(value) {
    this.counter += value;
  },

  // Note: it only works in this particular order:
  // `@observes()` first, then `@debounce()`
  @observes("prop")
  @debounce(50)
  react() {
    this.otherCounter++;
  },
});

module("Unit | Utils | decorators", function (hooks) {
  setupRenderingTest(hooks);

  test("afterRender", async function (assert) {
    this.registry.register("component:foo-component", fooComponent);
    this.set("baz", 0);

    await render(hbs`<FooComponent @baz={{this.baz}} />`);

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

  test("debounce", async function (assert) {
    const stub = TestStub.create();

    stub.increment(1);
    stub.increment(1);
    stub.increment(1);
    await settled();

    assert.strictEqual(stub.counter, 1);

    stub.increment(500);
    stub.increment(1000);
    stub.increment(5);
    await settled();

    assert.strictEqual(stub.counter, 6);
  });

  test("debounce works with @observe", async function (assert) {
    const stub = TestStub.create();

    stub.set("prop", 1);
    stub.set("prop", 2);
    stub.set("prop", 3);
    await settled();

    assert.strictEqual(stub.otherCounter, 1);
  });
});
