import { click, render, triggerKeyEvent } from "@ember/test-helpers";
import { setupRenderingTest } from "ember-qunit";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";

module("Integration | Component | image-grid-carousel", function (hooks) {
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

  test("it renders and navigates via buttons", async function (assert) {
    this.set("data", { items, mode: "focus" });

    await render(hbs`<ImageGridCarousel @data={{this.data}} />`);

    assert.dom(".d-image-grid__slide[data-index='0']").hasClass("is-active");

    await click(".d-image-grid__nav--next");
    assert.dom(".d-image-grid__slide[data-index='1']").hasClass("is-active");

    await click(".d-image-grid__nav--prev");
    assert.dom(".d-image-grid__slide[data-index='0']").hasClass("is-active");
  });

  test("it wraps around in focus mode", async function (assert) {
    this.set("data", { items, mode: "focus" });

    await render(hbs`<ImageGridCarousel @data={{this.data}} />`);

    assert.dom(".d-image-grid__slide[data-index='0']").hasClass("is-active");

    await click(".d-image-grid__nav--prev");
    assert.dom(".d-image-grid__slide[data-index='2']").hasClass("is-active");

    await click(".d-image-grid__nav--next");
    assert.dom(".d-image-grid__slide[data-index='0']").hasClass("is-active");
  });

  test("it handles keyboard navigation", async function (assert) {
    this.set("data", { items, mode: "focus" });

    await render(hbs`<ImageGridCarousel @data={{this.data}} />`);

    assert.dom(".d-image-grid__slide[data-index='0']").hasClass("is-active");

    await triggerKeyEvent(".d-image-grid__track", "keydown", "ArrowRight");
    assert.dom(".d-image-grid__slide[data-index='1']").hasClass("is-active");

    await triggerKeyEvent(".d-image-grid__track", "keydown", "ArrowLeft");
    assert.dom(".d-image-grid__slide[data-index='0']").hasClass("is-active");
  });

  test("it does not wrap around in grid mode (if ever supported by carousel)", async function (assert) {
    this.set("data", { items, mode: "grid" });

    await render(hbs`<ImageGridCarousel @data={{this.data}} />`);

    assert.dom(".d-image-grid__nav--prev").isDisabled();

    await click(".d-image-grid__nav--next");
    assert.dom(".d-image-grid__slide[data-index='1']").hasClass("is-active");
    assert.dom(".d-image-grid__nav--prev").isNotDisabled();
  });
});
