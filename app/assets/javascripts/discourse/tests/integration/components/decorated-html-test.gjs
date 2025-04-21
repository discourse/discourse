import { tracked } from "@glimmer/tracking";
import { htmlSafe } from "@ember/template";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import DecoratedHtml from "discourse/components/decorated-html";
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
});
