import Component from "@ember/component";
import EmberObject from "@ember/object";
import { clearRender, render, settled } from "@ember/test-helpers";
import { observes as nativeClassObserves } from "@ember-decorators/object";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { withSilencedDeprecations } from "discourse-common/lib/deprecated";
import discourseComputed, {
  afterRender,
  debounce,
  observes,
  on,
} from "discourse-common/utils/decorators";

// eslint-disable-next-line ember/no-classic-classes
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

// eslint-disable-next-line ember/no-classic-classes
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

// eslint-disable-next-line ember/no-classic-classes
const TestStub = EmberObject.extend({
  counter: 0,
  otherCounter: 0,
  state: null,

  @debounce(50)
  increment(value) {
    this.counter += value;
  },

  @debounce(50, true)
  setState(state) {
    this.state = state;
  },

  @observes("prop")
  propChanged() {
    this.react();
  },

  @debounce(50)
  react() {
    this.otherCounter++;
  },
});

const ClassSyntaxTestStub = class extends EmberObject {
  counter = 0;
  otherCounter = 0;
  state = null;

  @debounce(50)
  increment(value) {
    this.counter += value;
  }

  @debounce(50, true)
  setState(state) {
    this.state = state;
  }

  @nativeClassObserves("prop")
  propChanged() {
    this.react();
  }

  @debounce(50)
  react() {
    this.otherCounter++;
  }
};

module("Unit | Utils | decorators", function (hooks) {
  setupRenderingTest(hooks);

  test("afterRender", async function (assert) {
    this.registry.register("component:foo-component", fooComponent);
    this.set("baz", 0);

    await render(hbs`<FooComponent @baz={{this.baz}} />`);

    assert.dom(".foo-component").exists();
    assert.strictEqual(this.baz, 1);

    await clearRender();

    assert.dom(".foo-component").doesNotExist();
    assert.strictEqual(this.baz, 1);
  });

  test("discourseComputed works in EmberObject classes", async function (assert) {
    this.registry.register(
      "component:ember-object-component",
      EmberObjectComponent
    );

    this.set("name", "Jarek");
    await render(hbs`<EmberObjectComponent @name={{this.name}} />`);

    assert.dom(".ember-object-component").hasText("hello, Jarek");

    this.set("name", "Joffrey");
    assert
      .dom(".ember-object-component")
      .hasText(
        "hello, Joffrey",
        "rerenders the component when arguments change"
      );
  });

  test("discourseComputed works in native classes", async function (assert) {
    this.registry.register("component:native-component", NativeComponent);

    this.set("name", "Jarek");
    await render(hbs`<NativeComponent @name={{this.name}} />`);

    assert.dom(".native-component").hasText("hello, Jarek");

    this.set("name", "Joffrey");
    assert
      .dom(".native-component")
      .hasText(
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

  test("immediate debounce", async function (assert) {
    const stub = TestStub.create();

    stub.setState("foo");
    stub.setState("bar");
    await settled();

    assert.strictEqual(stub.state, "foo");
  });

  test("debounce works with native class syntax", async function (assert) {
    const stub = ClassSyntaxTestStub.create();

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

  test("@observes works via .extend and native class syntax", async function (assert) {
    let NativeClassWithObserver;
    withSilencedDeprecations("discourse.utils-decorators-observes", () => {
      NativeClassWithObserver = class extends EmberObject {
        counter = 0;
        @observes("value")
        incrementCounter() {
          this.set("counter", this.counter + 1);
        }
      };
    });

    // eslint-disable-next-line ember/no-classic-classes
    const ExtendWithObserver = EmberObject.extend({
      counter: 0,
      @observes("value")
      incrementCounter() {
        this.set("counter", this.counter + 1);
      },
    });

    const nativeClassTest = NativeClassWithObserver.create();
    nativeClassTest.set("value", "one");
    await settled();
    nativeClassTest.set("value", "two");
    await settled();
    assert.strictEqual(
      nativeClassTest.counter,
      2,
      "observer triggered for native class"
    );

    const extendTest = ExtendWithObserver.create();
    extendTest.set("value", "one");
    await settled();
    extendTest.set("value", "two");
    await settled();
    assert.strictEqual(extendTest.counter, 2, "observer triggered for .extend");
  });

  test("@on works via .extend and native class syntax", async function (assert) {
    let NativeClassWithOn;
    withSilencedDeprecations("discourse.utils-decorators-on", () => {
      NativeClassWithOn = class extends EmberObject {
        counter = 0;
        @on("init")
        incrementCounter() {
          this.set("counter", this.counter + 1);
        }
      };
    });

    // eslint-disable-next-line ember/no-classic-classes
    const ExtendWithOn = EmberObject.extend({
      counter: 0,
      @on("init")
      incrementCounter() {
        this.set("counter", this.counter + 1);
      },
    });

    const nativeClassTest = NativeClassWithOn.create();
    assert.strictEqual(
      nativeClassTest.counter,
      1,
      "on triggered for native class"
    );

    const extendTest = ExtendWithOn.create();
    assert.strictEqual(extendTest.counter, 1, "on triggered for .extend");
  });
});
