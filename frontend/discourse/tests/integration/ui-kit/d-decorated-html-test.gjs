import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import { trustHTML } from "@ember/template";
import {
  clearRender,
  find,
  render,
  settled,
  triggerEvent,
} from "@ember/test-helpers";
import curryComponent from "ember-curry-component";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DDecoratedHtml, {
  registerHtmlDecorator,
} from "discourse/ui-kit/d-decorated-html";

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

  test("defers replacement until the pressed control receives its click", async function (assert) {
    const state = new (class {
      @tracked html = trustHTML('<button id="target">Initial</button>');
    })();
    let clicks = 0;
    const decorate = (element, helper) => {
      element.querySelector("button").addEventListener("click", () => clicks++);
      helper.renderGlimmer(
        element,
        <template>
          <span id="nested">Nested content</span>
        </template>
      );
    };
    await render(
      <template>
        <DDecoratedHtml
          @html={{state.html}}
          @preservePointerTarget={{true}}
          @decorate={{decorate}}
        />
      </template>
    );
    const target = find("#target");
    await triggerEvent(target, "pointerdown", {
      button: 0,
      isPrimary: true,
      pointerId: 1,
    });
    state.html = trustHTML('<button id="target">Updated</button>');
    await settled();
    assert.strictEqual(
      find("#target"),
      target,
      "the pressed DOM node is retained"
    );
    assert
      .dom("#nested")
      .hasText(
        "Nested content",
        "nested components survive deferred rendering"
      );
    state.html = trustHTML('<button id="target">Updated again</button>');
    await settled();
    target.addEventListener("pointerup", (event) => event.stopPropagation());
    target.dispatchEvent(
      new PointerEvent("pointerup", { bubbles: true, button: 0, pointerId: 1 })
    );
    target.click();
    await settled();
    assert.strictEqual(
      clicks,
      1,
      "the original control receives its activation"
    );
    assert
      .dom("#target")
      .hasText("Updated again", "the newest HTML appears after click");
    assert
      .dom("#nested")
      .hasText("Nested content", "nested components render in the replacement");
    for (let i = 0; i < 3; i++) {
      state.html = trustHTML(`<button id="target">Update ${i}</button>`);
      await settled();
      assert
        .dom("#nested")
        .exists(
          { count: 1 },
          "old nested components are removed on each replacement"
        );
    }
  });

  test("ignores descendant blur but releases on window blur", async function (assert) {
    const state = new (class {
      @tracked html = trustHTML('<button id="target">Initial</button>');
    })();
    await render(
      <template>
        <DDecoratedHtml @html={{state.html}} @preservePointerTarget={{true}} />
      </template>
    );
    const target = find("#target");
    await triggerEvent(target, "pointerdown", {
      button: 0,
      isPrimary: true,
      pointerId: 1,
    });
    target.dispatchEvent(new FocusEvent("blur"));
    state.html = trustHTML('<button id="target">Updated</button>');
    await settled();
    assert.strictEqual(
      find("#target"),
      target,
      "losing focus does not cancel the press"
    );
    assert.dom(target).hasText("Initial", "replacement remains deferred");

    window.dispatchEvent(new FocusEvent("blur"));
    await settled();
    assert
      .dom("#target")
      .hasText("Updated", "leaving the window releases the update");
  });

  test("releases deferred HTML on pointer cancellation", async function (assert) {
    const state = new (class {
      @tracked html = trustHTML('<button id="target">Initial</button>');
    })();
    await render(
      <template>
        <DDecoratedHtml @html={{state.html}} @preservePointerTarget={{true}} />
      </template>
    );
    const target = find("#target");
    await triggerEvent(target, "pointerdown", {
      button: 0,
      isPrimary: true,
      pointerId: 1,
    });
    state.html = trustHTML('<button id="target">Updated</button>');
    await settled();
    await triggerEvent(target, "pointercancel", { pointerId: 1 });

    assert
      .dom("#target")
      .hasText("Updated", "cancellation releases the deferred update");
    await triggerEvent(find("#target"), "pointerdown", {
      button: 0,
      isPrimary: true,
      pointerId: 1,
    });
    await clearRender();
    await triggerEvent(document, "pointerup", { pointerId: 1 });
    assert
      .dom("#target")
      .doesNotExist(
        "a late release after destruction does not recreate content"
      );
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
