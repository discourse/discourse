import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DSkeleton from "discourse/ui-kit/d-skeleton";

module("Integration | UI Kit | d-skeleton", function (hooks) {
  setupRenderingTest(hooks);

  test("defaults to a single animated text item", async function (assert) {
    await render(<template><DSkeleton /></template>);

    assert.dom(".d-skeleton").exists();
    assert.dom(".d-skeleton__item").exists({ count: 1 });
    assert.dom(".d-skeleton__item").hasClass("d-skeleton__item--text");
    assert
      .dom(".d-skeleton__item")
      .hasClass("placeholder-animation", "the shimmer class is applied");
    assert
      .dom(".d-skeleton")
      .hasAttribute("aria-hidden", "true", "it is hidden from assistive tech");
  });

  test("@variant selects the shape and @count repeats the item", async function (assert) {
    await render(
      <template><DSkeleton @variant="circle" @count={{3}} /></template>
    );

    assert.dom(".d-skeleton__item").exists({ count: 3 });
    assert.dom(".d-skeleton__item--circle").exists({ count: 3 });
  });

  test("@animated={{false}} drops the shimmer but keeps a visible fill", async function (assert) {
    await render(<template><DSkeleton @animated={{false}} /></template>);

    // The static fill (a real background) must remain so the placeholder still
    // reads with the shimmer suppressed (also the reduced-motion case).
    assert
      .dom(".d-skeleton__item")
      .doesNotHaveClass(
        "placeholder-animation",
        "the shimmer class is omitted"
      );
    assert.dom(".d-skeleton__item").hasClass("d-skeleton__item--text");
  });

  test("dimensions apply via inline style", async function (assert) {
    await render(
      <template>
        <DSkeleton @variant="rect" @width="50%" @height="4em" @radius="1em" />
      </template>
    );

    // Match the inline style attribute rather than computed style, which would
    // resolve relative units (%/em) to pixels.
    assert.dom(".d-skeleton__item").hasAttribute("style", /width:\s*50%/);
    assert.dom(".d-skeleton__item").hasAttribute("style", /height:\s*4em/);
    assert
      .dom(".d-skeleton__item")
      .hasAttribute("style", /border-radius:\s*1em/);
  });

  test("@size is a square shorthand", async function (assert) {
    await render(
      <template><DSkeleton @variant="circle" @size="3em" /></template>
    );

    assert.dom(".d-skeleton__item").hasAttribute("style", /width:\s*3em/);
    assert.dom(".d-skeleton__item").hasAttribute("style", /height:\s*3em/);
  });

  test("forwards attributes to the root element", async function (assert) {
    await render(
      <template><DSkeleton class="extra" data-test-skeleton="yes" /></template>
    );

    assert.dom(".d-skeleton").hasClass("extra");
    assert.dom(".d-skeleton").hasAttribute("data-test-skeleton", "yes");
  });
});
