import Component from "@ember/component";
import Service from "@ember/service";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import optionalService from "discourse/lib/optional-service";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

class FooService extends Service {
  name = "foo";
}

class BarService extends Service {
  name = "bar";
}

// eslint-disable-next-line ember/no-classic-classes
const EmberObjectComponent = Component.extend({
  name: "",
  layout: hbs`<span class="ember-object-component">{{this.foo.name}} {{this.baz.name}}</span>`,

  foo: optionalService(),
  baz: optionalService("bar"),
});

class NativeComponent extends Component {
  @optionalService foo;
  @optionalService("bar") baz;

  name = "";
  layout = hbs`<span class="native-component">{{this.foo.name}} {{this.baz.name}}</span>`;
}

module("Unit | Utils | optional-service", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.registry.register("service:foo", FooService);
    this.registry.register("service:bar", BarService);
  });

  test("optionalService works in EmberObject classes", async function (assert) {
    this.registry.register(
      "component:ember-object-component",
      EmberObjectComponent
    );

    await render(hbs`<EmberObjectComponent />`);

    assert.dom(".ember-object-component").hasText("foo bar");
  });

  test("optionalService works in native classes", async function (assert) {
    this.registry.register("component:native-component", NativeComponent);

    await render(hbs`<NativeComponent />`);

    assert.dom(".native-component").hasText("foo bar");
  });
});
