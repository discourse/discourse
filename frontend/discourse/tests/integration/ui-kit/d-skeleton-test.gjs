import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DSkeleton from "discourse/ui-kit/d-skeleton";

let consumerSheet;

/**
 * Adds a rule the way a consumer's stylesheet would, at the *top* of the head so
 * it loses on source order. It can then only take effect by outranking the
 * component's defaults, which is what declaring them at zero specificity buys.
 */
function consumerRule(css) {
  consumerSheet = document.createElement("style");
  consumerSheet.textContent = css;
  document.head.insertBefore(consumerSheet, document.head.firstChild);
}

/**
 * Whether the wrapper has a real gap. An invalidated gap computes to `normal`,
 * so this distinguishes it from both zero and a length.
 */
function assertPositiveRowGap(assert, message) {
  const gap = getComputedStyle(document.querySelector(".d-skeleton")).rowGap;
  assert.strictEqual(parseFloat(gap) > 0, true, `${message} (got ${gap})`);
}

module("Integration | ui-kit | DSkeleton", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    consumerSheet?.remove();
    consumerSheet = null;
  });

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
      <template><DSkeleton @count={{3}} @variant="circle" /></template>
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
    assert
      .dom(".d-skeleton__item")
      .doesNotHaveStyle(
        { backgroundColor: "rgba(0, 0, 0, 0)" },
        "a fill still paints without the shimmer"
      );
  });

  test("dimensions apply via inline custom properties", async function (assert) {
    await render(
      <template>
        <DSkeleton @height="4em" @radius="1em" @variant="rect" @width="50%" />
      </template>
    );

    // Match the inline style attribute, not computed style, which would
    // resolve relative units (%/em) to pixels. They sit on the wrapper and
    // reach the items by inheritance.
    assert
      .dom(".d-skeleton")
      .hasAttribute("style", /--d-skeleton-item-width:\s*50%/);
    assert
      .dom(".d-skeleton")
      .hasAttribute("style", /--d-skeleton-item-height:\s*4em/);
    assert
      .dom(".d-skeleton")
      .hasAttribute("style", /--d-skeleton-radius:\s*1em/);
  });

  test("@count coerces to a sane number of items", async function (assert) {
    // `@count` reaches the component from callers that only assert its type, so
    // every one of these is a value it can actually be handed at runtime. A
    // non-finite count carries no intent and falls back to the default; a
    // finite one is clamped.
    const cases = [
      { count: NaN, expected: 1, label: "NaN" },
      { count: "abc", expected: 1, label: "a non-numeric string" },
      { count: "3", expected: 3, label: "a numeric string" },
      { count: Infinity, expected: 1, label: "Infinity" },
      { count: 1e9, expected: 50, label: "an oversized but finite count" },
      { count: 0, expected: 1, label: "zero" },
      { count: -3, expected: 1, label: "a negative count" },
      { count: 2.7, expected: 2, label: "a fractional count" },
    ];

    for (const { count, expected, label } of cases) {
      await render(<template><DSkeleton @count={{count}} /></template>);
      assert
        .dom(".d-skeleton__item")
        .exists({ count: expected }, `${label} renders ${expected}`);
    }
  });

  test("an unknown @variant falls back to text", async function (assert) {
    await render(<template><DSkeleton @variant="blob" /></template>);

    assert.dom(".d-skeleton").hasClass("d-skeleton--text");
    assert.dom(".d-skeleton__item").hasClass("d-skeleton__item--text");
  });

  test("a dimension value cannot introduce extra declarations", async function (assert) {
    await render(
      <template><DSkeleton @width="1px;position:fixed;inset:0" /></template>
    );

    assert
      .dom(".d-skeleton")
      .doesNotHaveStyle(
        { position: "fixed" },
        "the wrapper does not take an injected declaration"
      );
    assert
      .dom(".d-skeleton__item")
      .doesNotHaveStyle(
        { position: "fixed" },
        "the item does not take an injected declaration"
      );
  });

  test("a computed dimension value survives validation", async function (assert) {
    await render(
      <template>
        <DSkeleton
          @height="var(--d-input-height)"
          @variant="rect"
          @width="calc(100% - 2ch)"
        />
      </template>
    );

    assert
      .dom(".d-skeleton")
      .hasAttribute(
        "style",
        /--d-skeleton-item-width:\s*calc\(100% - 2ch\)/,
        "calc() is not rejected"
      );
    assert
      .dom(".d-skeleton")
      .hasAttribute(
        "style",
        /--d-skeleton-item-height:\s*var\(--d-input-height\)/,
        "var() is not rejected"
      );
  });

  test("@lastLineWidth tapers only the final line of a multi-line block", async function (assert) {
    await render(
      <template>
        <DSkeleton
          @count={{3}}
          @lastLineWidth="55%"
          @variant="text"
          @width="100%"
        />
      </template>
    );

    const items = [...document.querySelectorAll(".d-skeleton__item")];
    assert.strictEqual(items.length, 3, "renders one item per line");

    // The shared width sits on the wrapper; only the tapered final line carries
    // an override of its own.
    assert
      .dom(".d-skeleton")
      .hasAttribute("style", /--d-skeleton-item-width:\s*100%/);
    assert.dom(items[0]).doesNotHaveAttribute("style");
    assert.dom(items[1]).doesNotHaveAttribute("style");
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
        <DSkeleton @lastLineWidth="55%" @variant="text" @width="100%" />
      </template>
    );

    assert
      .dom(".d-skeleton")
      .hasAttribute(
        "style",
        /--d-skeleton-item-width:\s*100%/,
        "a lone line keeps the full width"
      );
    assert
      .dom(".d-skeleton__item")
      .doesNotHaveAttribute("style", "the lone line takes no taper override");
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
    assert
      .dom(".d-skeleton")
      .doesNotHaveStyle({ rowGap: "0px" }, "stacked lines are spaced apart");
    const stackedHeight = getComputedStyle(
      document.querySelector(".d-skeleton__item")
    ).height;

    await render(<template><DSkeleton /></template>);
    assert
      .dom(".d-skeleton")
      .doesNotHaveClass(
        "d-skeleton--multiline",
        "a lone bar matches its element's full line box"
      );
    assert.notStrictEqual(
      getComputedStyle(document.querySelector(".d-skeleton__item")).height,
      stackedHeight,
      "a lone bar takes the line box, a stacked one only its ink height"
    );
  });

  test("a tall @height does not collapse the derived gap", async function (assert) {
    // The gap subtracts the item height from the line box, so a height taller
    // than the line box would bottom out and leave the bars touching.
    await render(<template><DSkeleton @count={{3}} @height="3em" /></template>);

    // Not `!== "0px"`: an invalidated gap computes to `normal`, which would pass
    // that assertion while still rendering no separation at all.
    assertPositiveRowGap(assert, "the gap is a real length");
  });

  test("a CSS-wide keyword is not accepted as a dimension", async function (assert) {
    // `CSS.supports` accepts `initial`/`inherit`/`unset` for any property, but
    // stored in a custom property they are guaranteed-invalid, which would take
    // the derived gap down with them.
    await render(
      <template><DSkeleton @count={{3}} @height="initial" /></template>
    );

    assert
      .dom(".d-skeleton")
      .doesNotHaveAttribute("style", "the keyword is rejected outright");
    assertPositiveRowGap(assert, "the gap survives");
  });

  test("an unresolved var() dimension does not collapse the gap", async function (assert) {
    // Unlike a keyword this has to be accepted — a var() reference is exactly
    // what callers pass — so the gap carries its own fallback instead.
    await render(
      <template>
        <DSkeleton @count={{3}} @height="var(--not-a-real-token)" />
      </template>
    );

    assert
      .dom(".d-skeleton")
      .hasAttribute(
        "style",
        /--d-skeleton-item-height/,
        "the value is accepted"
      );
    assertPositiveRowGap(assert, "the gap survives");
  });

  test('@height="auto" does not close the gap between lines', async function (assert) {
    // `auto` is valid for `height`, so validation cannot reject it, and it is
    // uncomputable in a subtraction. The line rhythm is therefore independent of
    // whatever height the caller asks for.
    await render(
      <template><DSkeleton @count={{3}} @height="auto" /></template>
    );

    assertPositiveRowGap(assert, "the gap does not depend on the caller");
  });

  test("an ancestor cannot square off a circle", async function (assert) {
    // Radius is themeable from an ancestor, with the circle a deliberate
    // exception: its 50% is what makes it a circle, not a style choice.
    consumerRule(".squared-region { --d-skeleton-radius: 2px; }");
    await render(
      <template>
        <div class="squared-region"><DSkeleton @variant="circle" /></div>
      </template>
    );

    assert.dom(".d-skeleton__item").hasStyle({ borderRadius: "50%" });
  });

  test("@size is a square shorthand", async function (assert) {
    await render(
      <template><DSkeleton @size="3em" @variant="circle" /></template>
    );

    assert
      .dom(".d-skeleton")
      .hasAttribute("style", /--d-skeleton-item-width:\s*3em/);
    assert
      .dom(".d-skeleton")
      .hasAttribute("style", /--d-skeleton-item-height:\s*3em/);
  });

  test("@width wins over the @size shorthand", async function (assert) {
    await render(
      <template>
        <DSkeleton @size="3em" @variant="circle" @width="8em" />
      </template>
    );

    assert
      .dom(".d-skeleton")
      .hasAttribute("style", /--d-skeleton-item-width:\s*8em/);
    assert
      .dom(".d-skeleton")
      .hasAttribute(
        "style",
        /--d-skeleton-item-height:\s*3em/,
        "@size still supplies the height"
      );
  });

  test("@radius overrides the circle default", async function (assert) {
    await render(
      <template>
        <DSkeleton @radius="4px" @size="3em" @variant="circle" />
      </template>
    );

    assert
      .dom(".d-skeleton__item")
      .hasStyle(
        { borderRadius: "4px" },
        "the inline radius beats the variant's 50%"
      );
  });

  test("a variant's tokens beat the base defaults", async function (assert) {
    // The base block declares a width of `auto` and the circle one overrides it,
    // both at zero specificity, so this rests on source order and would break
    // silently if the blocks were reordered.
    await render(<template><DSkeleton @variant="circle" /></template>);

    const { width, height } = getComputedStyle(
      document.querySelector(".d-skeleton__item")
    );
    assert.strictEqual(
      width,
      height,
      "the circle sizes both axes rather than stretching to the base `auto`"
    );
    assert.dom(".d-skeleton__item").hasStyle({ borderRadius: "50%" });
  });

  test("--d-skeleton-duration retimes the shimmer", async function (assert) {
    consumerRule(".slow-skeleton { --d-skeleton-duration: 9s; }");
    await render(<template><DSkeleton class="slow-skeleton" /></template>);

    assert.dom(".d-skeleton__item").hasStyle({ animationDuration: "9s" });
  });

  test("--d-skeleton-display puts the placeholder in inline flow", async function (assert) {
    await render(<template><DSkeleton /></template>);
    assert
      .dom(".d-skeleton")
      .hasStyle({ display: "flex" }, "it is block-level by default");

    consumerRule(".inline-skeleton { --d-skeleton-display: inline-flex; }");
    await render(<template><DSkeleton class="inline-skeleton" /></template>);

    assert.dom(".d-skeleton").hasStyle({ display: "inline-flex" });
  });

  test("a theming token can be scoped from an ancestor", async function (assert) {
    consumerRule(".themed-region { --d-skeleton-duration: 9s; }");
    await render(
      <template>
        <div class="themed-region"><DSkeleton /></div>
      </template>
    );

    assert.dom(".d-skeleton__item").hasStyle({ animationDuration: "9s" });
  });

  test("layout tokens do not leak in from an ancestor", async function (assert) {
    // The counterpart to the test above: a container retinting its skeletons is
    // meaningful, a container silently relaying out every nested one is not.
    consumerRule(
      ".layout-region { --d-skeleton-display: inline-flex; --d-skeleton-item-width: 5em; }"
    );
    await render(
      <template>
        <div class="layout-region"><DSkeleton /></div>
      </template>
    );

    assert
      .dom(".d-skeleton")
      .hasStyle({ display: "flex" }, "display stays the component's own");
    assert
      .dom(".d-skeleton__item")
      .doesNotHaveStyle({ width: "80px" }, "the item keeps its own sizing");
  });

  test("a consumer style is discarded, so the dimensions survive", async function (assert) {
    // `style` carries the dimensions, so the component keeps it by declaring it
    // after ...attributes. Everything a caller legitimately needs is a token.
    await render(
      <template><DSkeleton style="margin-top: 1em" @width="8ch" /></template>
    );

    assert
      .dom(".d-skeleton")
      .hasAttribute("style", /--d-skeleton-item-width:\s*8ch/);
    assert.dom(".d-skeleton").doesNotHaveStyle({ marginTop: "16px" });

    await render(<template><DSkeleton style="margin-top: 1em" /></template>);
    assert
      .dom(".d-skeleton")
      .doesNotHaveStyle(
        { marginTop: "16px" },
        "also when there are no dimensions to set"
      );
  });

  test("aria-hidden can be overridden through ...attributes", async function (assert) {
    await render(<template><DSkeleton aria-hidden="false" /></template>);

    assert.dom(".d-skeleton").hasAttribute("aria-hidden", "false");
  });

  test("forwards attributes to the root element", async function (assert) {
    await render(
      <template><DSkeleton class="extra" data-test-skeleton="yes" /></template>
    );

    assert.dom(".d-skeleton").hasClass("extra");
    assert.dom(".d-skeleton").hasAttribute("data-test-skeleton", "yes");
  });
});
