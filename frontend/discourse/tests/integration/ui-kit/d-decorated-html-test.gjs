import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import { trustHTML } from "@ember/template";
import { render, settled } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import curryComponent from "ember-curry-component";
import { module, test } from "qunit";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DDecoratedHtml, {
  registerHtmlDecorator,
} from "discourse/ui-kit/d-decorated-html";
import { WIDGET_DECOMMISSION_OPTIONS } from "discourse/widgets/widget";

module("Integration | ui-kit | DDecoratedHtml", function (hooks) {
  setupRenderingTest(hooks);

  test("renders and re-renders content", async function (assert) {
    const state = new (class {
      @tracked html = trustHTML("<h1>Initial</h1>");
    })();

    await render(<template><DDecoratedHtml @html={{state.html}} /></template>);

    assert.dom("h1").hasText("Initial");

    state.html = trustHTML("<h1>Updated</h1>");
    await settled();

    assert.dom("h1").hasText("Updated");
  });

  test("can decorate content, including renderGlimmer", async function (assert) {
    const state = new (class {
      @tracked html = trustHTML("<h1>Initial</h1>");
    })();

    const decorate = (element, helper) => {
      element.innerHTML += "<div id='appended'>Appended</div>";
      helper.renderGlimmer(
        element,
        <template>
          <div id="render-glimmer">Hello from Glimmer Component</div>
        </template>
      );
    };

    await render(
      <template>
        <DDecoratedHtml @html={{state.html}} @decorate={{decorate}} />
      </template>
    );

    assert.dom("h1").hasText("Initial");
    assert.dom("#appended").hasText("Appended");
    assert.dom("#render-glimmer").hasText("Hello from Glimmer Component");
  });

  test("can decorate content with renderGlimmer using a curried component", async function (assert) {
    const state = new (class {
      @tracked html = trustHTML("<h1>Initial</h1>");
    })();

    const decorate = (element, helper) => {
      element.innerHTML += "<div id='appended'>Appended</div>";
      helper.renderGlimmer(
        element,
        curryComponent(
          <template>
            <div id="render-glimmer">Hello from {{@value}} Component</div>
          </template>,
          { value: "Curried" },
          getOwner(this)
        )
      );
    };

    await render(
      <template>
        <DDecoratedHtml @html={{state.html}} @decorate={{decorate}} />
      </template>
    );

    assert.dom("h1").hasText("Initial");
    assert.dom("#appended").hasText("Appended");
    assert.dom("#render-glimmer").hasText("Hello from Curried Component");
  });

  test("renderGlimmer is ignored if receives invalid arguments", async function (assert) {
    const state = new (class {
      @tracked html = trustHTML("<h1>Initial</h1>");
    })();

    const decorateWithStringTarget = (element, helper) => {
      element.innerHTML += "<div id='appended'>Appended</div>";

      withSilencedDeprecations(WIDGET_DECOMMISSION_OPTIONS.id, () => {
        helper.renderGlimmer(
          "div",
          <template>
            <div id="render-glimmer">Hello from Glimmer Component</div>
          </template>
        );
      });
    };

    await render(
      <template>
        <DDecoratedHtml
          @html={{state.html}}
          @decorate={{decorateWithStringTarget}}
        />
      </template>
    );

    assert
      .dom("h1")
      .hasText(
        "Initial",
        "Initial content is rendered when a string is passed as the target element"
      );
    assert
      .dom("#appended")
      .hasText(
        "Appended",
        "Appended content is rendered when a string is passed as the target element"
      );
    assert
      .dom("#render-glimmer")
      .doesNotExist(
        "Glimmer component is not rendered when a string is passed as the target element"
      );

    const decorateWithHbsTemplate = (element, helper) => {
      element.innerHTML += "<div id='appended'>Appended</div>";

      withSilencedDeprecations(WIDGET_DECOMMISSION_OPTIONS.id, () => {
        helper.renderGlimmer(
          element,
          hbs("<div id='render-glimmer'>Hello from Glimmer Component</div>")
        );
      });
    };

    await render(
      <template>
        <DDecoratedHtml
          @html={{state.html}}
          @decorate={{decorateWithHbsTemplate}}
        />
      </template>
    );

    assert
      .dom("h1")
      .hasText(
        "Initial",
        "Initial content is rendered when a template is passed as the component"
      );
    assert
      .dom("#appended")
      .hasText(
        "Appended",
        "Appended content is rendered when a template is passed as the component"
      );
    assert
      .dom("#render-glimmer")
      .doesNotExist(
        "Glimmer component is not rendered when a template is passed as the component"
      );
  });

  test("applies registered HTML decorators by default", async function (assert) {
    let decoratorCalled = false;
    registerHtmlDecorator((element) => {
      decoratorCalled = true;
      element.innerHTML += "<span id='auto-decorated'>Decorated</span>";
    });

    await render(
      <template>
        <DDecoratedHtml @html={{trustHTML "<div>Content</div>"}} />
      </template>
    );

    assert.true(decoratorCalled, "registered decorator was called");
    assert.dom("#auto-decorated").hasText("Decorated");
  });

  test("custom @decorate function replaces default decoration", async function (assert) {
    let registeredDecoratorCalled = false;
    registerHtmlDecorator(() => {
      registeredDecoratorCalled = true;
    });

    let customDecoratorCalled = false;
    const customDecorator = (element) => {
      customDecoratorCalled = true;
      element.innerHTML += "<span id='custom'>Custom</span>";
    };

    await render(
      <template>
        <DDecoratedHtml
          @html={{trustHTML "<div>Content</div>"}}
          @decorate={{customDecorator}}
        />
      </template>
    );

    assert.true(customDecoratorCalled, "custom decorator was called");
    assert.false(
      registeredDecoratorCalled,
      "registered decorator was not called when custom decorator is provided"
    );
    assert.dom("#custom").hasText("Custom");
  });
});
