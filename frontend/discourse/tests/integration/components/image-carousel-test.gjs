import { click, render, triggerKeyEvent } from "@ember/test-helpers";
import { setupRenderingTest } from "ember-qunit";
import { module, test } from "qunit";
import ImageCarousel from "discourse/components/image-carousel";

module("Integration | Component | image-carousel", function (hooks) {
  setupRenderingTest(hooks);

  const items = [
    {
      element: document.createElement("div"),
      img: document.createElement("img"),
      width: 100,
      height: 100,
    },
    {
      element: document.createElement("div"),
      img: document.createElement("img"),
      width: 100,
      height: 100,
    },
    {
      element: document.createElement("div"),
      img: document.createElement("img"),
      width: 100,
      height: 100,
    },
  ];

  test("renders and navigates via buttons", async function (assert) {
    const data = { items };

    await render(<template><ImageCarousel @data={{data}} /></template>);

    assert
      .dom(".d-image-carousel__slide[data-index='0']")
      .hasClass("is-active");

    await click(".d-image-carousel__nav--next");
    assert
      .dom(".d-image-carousel__slide[data-index='1']")
      .hasClass("is-active");

    await click(".d-image-carousel__nav--prev");
    assert
      .dom(".d-image-carousel__slide[data-index='0']")
      .hasClass("is-active");
  });

  test("wraps around", async function (assert) {
    const data = { items };

    await render(<template><ImageCarousel @data={{data}} /></template>);

    assert
      .dom(".d-image-carousel__slide[data-index='0']")
      .hasClass("is-active");

    await click(".d-image-carousel__nav--prev");
    assert
      .dom(".d-image-carousel__slide[data-index='2']")
      .hasClass("is-active");

    await click(".d-image-carousel__nav--next");
    assert
      .dom(".d-image-carousel__slide[data-index='0']")
      .hasClass("is-active");
  });

  test("handles keyboard navigation", async function (assert) {
    const data = { items };

    await render(<template><ImageCarousel @data={{data}} /></template>);

    assert
      .dom(".d-image-carousel__slide[data-index='0']")
      .hasClass("is-active");

    await triggerKeyEvent(".d-image-carousel__track", "keydown", "ArrowRight");
    assert
      .dom(".d-image-carousel__slide[data-index='1']")
      .hasClass("is-active");

    await triggerKeyEvent(".d-image-carousel__track", "keydown", "ArrowLeft");
    assert
      .dom(".d-image-carousel__slide[data-index='0']")
      .hasClass("is-active");
  });
});
