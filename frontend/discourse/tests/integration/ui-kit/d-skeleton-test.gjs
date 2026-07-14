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

  test("dimensions apply via inline custom properties", async function (assert) {
    await render(
      <template>
        <DSkeleton @variant="rect" @width="50%" @height="4em" @radius="1em" />
      </template>
    );

    // Match the inline style attribute, not computed style, which would
    // resolve relative units (%/em) to pixels.
    assert
      .dom(".d-skeleton__item")
      .hasAttribute("style", /--d-skeleton-item-width:\s*50%/);
    assert
      .dom(".d-skeleton__item")
      .hasAttribute("style", /--d-skeleton-item-height:\s*4em/);
    assert
      .dom(".d-skeleton__item")
      .hasAttribute("style", /--d-skeleton-radius:\s*1em/);
  });

  test("@lastLineWidth tapers only the final line of a multi-line block", async function (assert) {
    await render(
      <template>
        <DSkeleton
          @variant="text"
          @count={{3}}
          @width="100%"
          @lastLineWidth="55%"
        />
      </template>
    );

    const items = [...document.querySelectorAll(".d-skeleton__item")];
    assert.strictEqual(items.length, 3, "renders one item per line");
    assert
      .dom(items[0])
      .hasAttribute("style", /--d-skeleton-item-width:\s*100%/);
    assert
      .dom(items[1])
      .hasAttribute("style", /--d-skeleton-item-width:\s*100%/);
    assert
      .dom(items[2])
      .hasAttribute(
        "style",
        /--d-skeleton-item-width:\s*55%/,
        "the last line is shorter"
      );
  });

  test("@lastLineWidth is ignored for a single item", async function (assert) {
    await render(
      <template>
        <DSkeleton @variant="text" @width="100%" @lastLineWidth="55%" />
      </template>
    );

    assert
      .dom(".d-skeleton__item")
      .hasAttribute(
        "style",
        /--d-skeleton-item-width:\s*100%/,
        "a lone line keeps the full width"
      );
  });

  test("stamps the variant on the wrapper for variant-specific styling", async function (assert) {
    await render(<template><DSkeleton @variant="text" /></template>);
    assert
      .dom(".d-skeleton")
      .hasClass(
        "d-skeleton--text",
        "the wrapper carries the variant so the scss can set its line rhythm"
      );
  });

  test("marks a stacked skeleton multiline, a lone one not", async function (assert) {
    await render(<template><DSkeleton @count={{3}} /></template>);
    assert
      .dom(".d-skeleton")
      .hasClass(
        "d-skeleton--multiline",
        "stacked items are multiline so text lines drop to ink height"
      );

    await render(<template><DSkeleton /></template>);
    assert
      .dom(".d-skeleton")
      .doesNotHaveClass(
        "d-skeleton--multiline",
        "a lone bar matches its element's full line box"
      );
  });

  test("@size is a square shorthand", async function (assert) {
    await render(
      <template><DSkeleton @variant="circle" @size="3em" /></template>
    );

    assert
      .dom(".d-skeleton__item")
      .hasAttribute("style", /--d-skeleton-item-width:\s*3em/);
    assert
      .dom(".d-skeleton__item")
      .hasAttribute("style", /--d-skeleton-item-height:\s*3em/);
  });

  test("forwards attributes to the root element", async function (assert) {
    await render(
      <template><DSkeleton class="extra" data-test-skeleton="yes" /></template>
    );

    assert.dom(".d-skeleton").hasClass("extra");
    assert.dom(".d-skeleton").hasAttribute("data-test-skeleton", "yes");
  });
});
