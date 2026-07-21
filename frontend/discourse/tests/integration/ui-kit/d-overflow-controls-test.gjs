import { click, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DOverflowControls from "discourse/ui-kit/d-overflow-controls";

async function scrollTo(selector, props) {
  const element = document.querySelector(selector);
  Object.assign(element, props);
  await triggerEvent(element, "scroll");
}

module("Integration | ui-kit | DOverflowControls", function (hooks) {
  setupRenderingTest(hooks);

  test("no buttons when content fits", async function (assert) {
    await render(
      <template>
        <DOverflowControls style="width: 200px; overflow: auto">
          <div style="width: 50px; height: 20px"></div>
        </DOverflowControls>
      </template>
    );

    assert.dom(".d-overflow-controls__btn").doesNotExist();
  });

  test("no buttons when the overflowing axis is not scrollable", async function (assert) {
    await render(
      <template>
        {{! content overflows horizontally but the axis is clipped, not scrollable }}
        <DOverflowControls style="width: 100px; overflow: hidden">
          <div style="width: 500px; height: 20px"></div>
        </DOverflowControls>
      </template>
    );

    assert.dom(".d-overflow-controls__btn").doesNotExist();
  });

  test("horizontal overflow shows the trailing button, then the leading one", async function (assert) {
    await render(
      <template>
        <DOverflowControls style="width: 100px; overflow-x: auto">
          <div style="width: 500px; height: 20px"></div>
        </DOverflowControls>
      </template>
    );

    assert
      .dom(".d-overflow-controls__btn.--right")
      .exists("shows the scroll-right button at the start");
    assert
      .dom(".d-overflow-controls__btn.--left")
      .doesNotExist("hides the scroll-left button at the start");

    const content = document.querySelector(".d-overflow-controls__content");
    await scrollTo(".d-overflow-controls__content", {
      scrollLeft: content.scrollWidth,
    });

    assert
      .dom(".d-overflow-controls__btn.--left")
      .exists("shows the scroll-left button at the end");
    assert
      .dom(".d-overflow-controls__btn.--right")
      .doesNotExist("hides the scroll-right button at the end");
  });

  test("vertical overflow shows the bottom button, then the top one", async function (assert) {
    await render(
      <template>
        <DOverflowControls style="height: 100px; overflow-y: auto">
          <div style="height: 500px; width: 20px"></div>
        </DOverflowControls>
      </template>
    );

    assert
      .dom(".d-overflow-controls__btn.--down")
      .exists("shows the scroll-down button at the top");
    assert
      .dom(".d-overflow-controls__btn.--up")
      .doesNotExist("hides the scroll-up button at the top");

    const content = document.querySelector(".d-overflow-controls__content");
    await scrollTo(".d-overflow-controls__content", {
      scrollTop: content.scrollHeight,
    });

    assert
      .dom(".d-overflow-controls__btn.--up")
      .exists("shows the scroll-up button at the bottom");
    assert
      .dom(".d-overflow-controls__btn.--down")
      .doesNotExist("hides the scroll-down button at the bottom");
  });

  test("clamps button scroll targets to the content edges", async function (assert) {
    await render(
      <template>
        <DOverflowControls style="width: 100px; overflow-x: auto">
          <div style="width: 500px; height: 20px"></div>
        </DOverflowControls>
      </template>
    );

    const content = document.querySelector(".d-overflow-controls__content");
    let target;
    content.scrollTo = (options) => (target = options);

    await scrollTo(".d-overflow-controls__content", { scrollLeft: 350 });
    await click(".d-overflow-controls__btn.--right");
    assert.deepEqual(
      target,
      { left: 400, behavior: "smooth" },
      "forward tap targets the right edge instead of overshooting"
    );

    await scrollTo(".d-overflow-controls__content", { scrollLeft: 50 });
    await click(".d-overflow-controls__btn.--left");
    assert.deepEqual(
      target,
      { left: 0, behavior: "smooth" },
      "backward tap targets the start instead of overshooting"
    );
  });

  test("targets only the tapped axis when both axes overflow", async function (assert) {
    await render(
      <template>
        {{! scrollbar-width: none keeps offset sizes exact across platforms }}
        <DOverflowControls
          style="width: 100px; height: 100px; overflow: auto; scrollbar-width: none"
        >
          <div style="width: 500px; height: 500px"></div>
        </DOverflowControls>
      </template>
    );

    const content = document.querySelector(".d-overflow-controls__content");
    let target;
    content.scrollTo = (options) => (target = options);

    await scrollTo(".d-overflow-controls__content", {
      scrollLeft: 50,
      scrollTop: 50,
    });

    await click(".d-overflow-controls__btn.--right");
    assert.deepEqual(
      target,
      { left: 150, behavior: "smooth" },
      "horizontal tap targets the horizontal axis only"
    );

    await click(".d-overflow-controls__btn.--down");
    assert.deepEqual(
      target,
      { top: 150, behavior: "smooth" },
      "vertical tap targets the vertical axis only"
    );
  });

  test("applies consumer classes and attributes", async function (assert) {
    await render(
      <template>
        <DOverflowControls
          @wrapperClass="my-wrap"
          @class="my-content"
          @buttonClass="my-btn"
          style="width: 100px; overflow-x: auto"
          data-test="yes"
        >
          <div style="width: 500px; height: 20px"></div>
        </DOverflowControls>
      </template>
    );

    assert
      .dom(".d-overflow-controls.my-wrap")
      .exists("wrapper gets @wrapperClass");
    assert
      .dom(".d-overflow-controls__content.my-content")
      .hasAttribute(
        "data-test",
        "yes",
        "content gets @class and ...attributes"
      );
    assert
      .dom(".d-overflow-controls__btn.my-btn")
      .exists("buttons get @buttonClass");
  });
});
