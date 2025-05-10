import { tracked } from "@glimmer/tracking";
import { htmlSafe } from "@ember/template";
import { render, settled } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import curryComponent from "ember-curry-component";
import { module, test } from "qunit";
import DecoratedHtml from "discourse/components/decorated-html";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | <DecoratedHtml />", function (hooks) {
  setupRenderingTest(hooks);

  test("renders and re-renders content", async function (assert) {
    const state = new (class {
      @tracked html = htmlSafe("<h1>Initial</h1>");
    })();

    await render(<template><DecoratedHtml @html={{state.html}} /></template>);

    assert.dom("h1").hasText("Initial");

    state.html = htmlSafe("<h1>Updated</h1>");
    await settled();

    assert.dom("h1").hasText("Updated");
  });

  test("can decorate content, including renderGlimmer", async function (assert) {
    const state = new (class {
      @tracked html = htmlSafe("<h1>Initial</h1>");
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
        <DecoratedHtml @html={{state.html}} @decorate={{decorate}} />
      </template>
    );

    assert.dom("h1").hasText("Initial");
    assert.dom("#appended").hasText("Appended");
    assert.dom("#render-glimmer").hasText("Hello from Glimmer Component");
  });

  test("can decorate content with renderGlimmer using a curried componet", async function (assert) {
    const state = new (class {
      @tracked html = htmlSafe("<h1>Initial</h1>");
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
          getOwnerWithFallback(this)
        )
      );
    };

    await render(
      <template>
        <DecoratedHtml @html={{state.html}} @decorate={{decorate}} />
      </template>
    );

    assert.dom("h1").hasText("Initial");
    assert.dom("#appended").hasText("Appended");
    assert.dom("#render-glimmer").hasText("Hello from Curried Component");
  });

  test("renderGlimmer is ignored if receives invalid arguments", async function (assert) {
    const state = new (class {
      @tracked html = htmlSafe("<h1>Initial</h1>");
    })();

    const decorateWithStringTarget = (element, helper) => {
      element.innerHTML += "<div id='appended'>Appended</div>";

      withSilencedDeprecations("discourse.post-stream-widget-overrides", () => {
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
        <DecoratedHtml
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

      withSilencedDeprecations("discourse.post-stream-widget-overrides", () => {
        helper.renderGlimmer(
          element,
          hbs("<div id='render-glimmer'>Hello from Glimmer Component</div>")
        );
      });
    };

    await render(
      <template>
        <DecoratedHtml
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
});
