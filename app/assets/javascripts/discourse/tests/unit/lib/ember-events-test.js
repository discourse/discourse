/* eslint-disable ember/no-classic-classes */

import GlimmerComponent from "@glimmer/component";
import ClassicComponent, { setComponentTemplate } from "@ember/component";
import { action } from "@ember/object";
import { click, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { setupRenderingTest } from "ember-qunit";
import { module, test } from "qunit";

// Configure test-local Classic and Glimmer components that
// will be immune from upgrades to actual Discourse components.
const ExampleClassicButton = setComponentTemplate(
  hbs`{{! template-lint-disable no-yield-only }}{{yield}}`,
  ClassicComponent.extend({
    tagName: "button",
    type: "button",
    preventEventPropagation: false,
    onClick: null,
    onMouseDown: null,

    click(event) {
      event.preventDefault();
      if (this.preventEventPropagation) {
        event.stopPropagation();
      }
      this.onClick?.(event);
    },
  })
);

const ExampleGlimmerButton = setComponentTemplate(
  hbs`
    <button {{on 'click' this.click}} type='button' ...attributes>
      {{yield}}
    </button>
  `,
  class extends GlimmerComponent {
    @action
    click(event) {
      event.preventDefault();
      if (this.args.preventEventPropagation) {
        event.stopPropagation();
      }
      this.args.onClick?.(event);
    }
  }
);

module("Unit | Lib | ember-events", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.owner.register(
      "component:example-classic-button",
      ExampleClassicButton
    );
    this.owner.register(
      "component:example-glimmer-button",
      ExampleGlimmerButton
    );
  });

  module("classic component event configuration", function () {
    test("it adds listeners for standard event handlers on the component prototype or the component itself", async function (assert) {
      let i = 0;

      this.setProperties({
        onOneClick: () => this.set("oneClicked", i++),
        onTwoClick: () => this.set("twoClicked", i++),
        oneClicked: undefined,
        twoClicked: undefined,
      });

      await render(hbs`
        <ExampleClassicButton id="buttonOne" @onClick={{this.onOneClick}} />
        <ExampleClassicButton id="buttonTwo" @click={{this.onTwoClick}} />
      `);

      await click("#buttonOne");
      await click("#buttonTwo");

      assert.strictEqual(this.oneClicked, 0);
      assert.strictEqual(this.twoClicked, 1);
    });

    test("it adds listeners for standard event handlers on the component itself or the component prototype (order reversed)", async function (assert) {
      let i = 0;

      this.setProperties({
        onOneClick: () => this.set("oneClicked", i++),
        onTwoClick: () => this.set("twoClicked", i++),
        oneClicked: undefined,
        twoClicked: undefined,
      });

      await render(hbs`
        <ExampleClassicButton id="buttonOne" @click={{this.onOneClick}} />
        <ExampleClassicButton id="buttonTwo" @onClick={{this.onTwoClick}} />
      `);

      await click("#buttonOne");
      await click("#buttonTwo");

      assert.strictEqual(this.oneClicked, 0);
      assert.strictEqual(this.twoClicked, 1);
    });
  });

  module("nested glimmer inside classic", function () {
    test("it handles click events and allows propagation by default", async function (assert) {
      let i = 0;

      this.setProperties({
        onParentClick: () => this.set("parentClicked", i++),
        onChildClick: () => this.set("childClicked", i++),
        parentClicked: undefined,
        childClicked: undefined,
      });

      await render(hbs`
        <ExampleClassicButton id="parentButton" @onClick={{this.onParentClick}}>
          <ExampleGlimmerButton id="childButton" @onClick={{this.onChildClick}} />
        </ExampleClassicButton>
      `);

      await click("#childButton");

      assert.strictEqual(this.childClicked, 0);
      assert.strictEqual(this.parentClicked, 1);
    });

    test("it handles click events and can prevent event propagation", async function (assert) {
      let i = 0;

      this.setProperties({
        onParentClick: () => this.set("parentClicked", i++),
        onChildClick: () => this.set("childClicked", i++),
        parentClicked: undefined,
        childClicked: undefined,
      });

      await render(hbs`
        <ExampleClassicButton id="parentButton" @onClick={{this.onParentClick}}>
          <ExampleGlimmerButton id="childButton" @preventEventPropagation={{true}} @onClick={{this.onChildClick}} />
        </ExampleClassicButton>
      `);

      await click("#childButton");

      assert.strictEqual(this.childClicked, 0);
      assert.strictEqual(this.parentClicked, undefined);
    });
  });

  module("nested classic inside glimmer", function () {
    test("it handles click events and allows propagation by default", async function (assert) {
      let i = 0;

      this.setProperties({
        onParentClick: () => this.set("parentClicked", i++),
        onChildClick: () => this.set("childClicked", i++),
        parentClicked: undefined,
        childClicked: undefined,
      });

      await render(hbs`
        <ExampleGlimmerButton id="parentButton" @onClick={{this.onParentClick}}>
          <ExampleClassicButton id="childButton" @onClick={{this.onChildClick}} />
        </ExampleGlimmerButton>
      `);

      await click("#childButton");

      assert.strictEqual(this.childClicked, 0);
      assert.strictEqual(this.parentClicked, 1);
    });

    test("it handles click events and can prevent event propagation", async function (assert) {
      let i = 0;

      this.setProperties({
        onParentClick: () => this.set("parentClicked", i++),
        onChildClick: () => this.set("childClicked", i++),
        parentClicked: undefined,
        childClicked: undefined,
      });

      await render(hbs`
        <ExampleGlimmerButton id="parentButton" @onClick={{this.onParentClick}}>
          <ExampleClassicButton id="childButton" @preventEventPropagation={{true}} @onClick={{this.onChildClick}} />
        </ExampleGlimmerButton>
      `);

      await click("#childButton");

      assert.strictEqual(this.childClicked, 0);
      assert.strictEqual(this.parentClicked, undefined);
    });
  });

  module("nested `{{action}}` usage inside classic", function () {
    test("it handles click events and allows propagation by default", async function (assert) {
      let i = 0;

      this.setProperties({
        onParentClick: () => this.set("parentClicked", i++),
        onChildClick: () => this.set("childClicked", i++),
        parentClicked: undefined,
        childClicked: undefined,
      });

      await render(hbs`
        <ExampleClassicButton id="parentButton" @onClick={{this.onParentClick}}>
          <button id="childButton" {{action this.onChildClick}} />
        </ExampleClassicButton>
      `);

      await click("#childButton");

      assert.strictEqual(this.childClicked, 0);
      assert.strictEqual(this.parentClicked, 1);
    });

    test("it handles click events and can prevent event propagation", async function (assert) {
      let i = 0;

      this.setProperties({
        onParentClick: () => this.set("parentClicked", i++),
        onChildClick: () => this.set("childClicked", i++),
        parentClicked: undefined,
        childClicked: undefined,
      });

      await render(hbs`
        <ExampleClassicButton id="parentButton" @onClick={{this.onParentClick}}>
          <button id="childButton" {{action this.onChildClick bubbles=false}} />
        </ExampleClassicButton>
      `);

      await click("#childButton");

      assert.strictEqual(this.childClicked, 0);
      assert.strictEqual(this.parentClicked, undefined);
    });
  });

  module("nested `{{action}}` usage inside glimmer", function () {
    test("it handles click events and allows propagation by default", async function (assert) {
      let i = 0;

      this.setProperties({
        onParentClick: () => this.set("parentClicked", i++),
        onChildClick: () => this.set("childClicked", i++),
        parentClicked: undefined,
        childClicked: undefined,
      });

      await render(hbs`
        <ExampleGlimmerButton id="parentButton" @onClick={{this.onParentClick}}>
          <button id="childButton" {{action this.onChildClick}} />
        </ExampleGlimmerButton>
      `);

      await click("#childButton");

      assert.strictEqual(this.childClicked, 0);
      assert.strictEqual(this.parentClicked, 1);
    });

    test("it handles click events and can prevent event propagation", async function (assert) {
      let i = 0;

      this.setProperties({
        onParentClick: () => this.set("parentClicked", i++),
        onChildClick: () => this.set("childClicked", i++),
        parentClicked: undefined,
        childClicked: undefined,
      });

      await render(hbs`
        <ExampleGlimmerButton id="parentButton" @onClick={{this.onParentClick}}>
          <button id="childButton" {{action this.onChildClick bubbles=false}} />
        </ExampleGlimmerButton>
      `);

      await click("#childButton");

      assert.strictEqual(this.childClicked, 0);
      assert.strictEqual(this.parentClicked, undefined);
    });
  });
});
