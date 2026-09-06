import { click, find, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const SOURCE = `import Thing from "discourse/thing";`;

module("Integration | Component | <StyleguideExample />", function (hooks) {
  setupRenderingTest(hooks);

  // An ungrouped page has only the page header's h1 above the card, so h2 is the level that
  // keeps the outline contiguous. h3 is for cards inside a group, whose own heading is the h2.
  test("titles default to h2", async function (assert) {
    await render(
      <template>
        <StyleguideExample @title="Buttons">demo</StyleguideExample>
      </template>
    );

    assert.dom("h2.styleguide-example__title").hasText("Buttons");
    assert.dom("h3.styleguide-example__title").doesNotExist();
  });

  test("renders h3 when nested in a group", async function (assert) {
    await render(
      <template>
        <StyleguideExample
          @title="Buttons"
          @headingLevel={{3}}
        >demo</StyleguideExample>
      </template>
    );

    assert.dom("h3.styleguide-example__title").hasText("Buttons");
    assert.dom("h2.styleguide-example__title").doesNotExist();
  });

  test("no code arg means no source toggle", async function (assert) {
    await render(
      <template>
        <StyleguideExample @title="Tokens">demo</StyleguideExample>
      </template>
    );

    assert
      .dom(".styleguide-example__code-toggle")
      .doesNotExist("a purely visual example offers nothing to reveal");
  });

  test("the source toggle reveals and hides the snippet", async function (assert) {
    await render(
      <template>
        <StyleguideExample
          @title="Buttons"
          @code={{SOURCE}}
        >demo</StyleguideExample>
      </template>
    );

    assert.dom(".styleguide-example__code").doesNotExist();
    assert
      .dom(".styleguide-example__code-toggle")
      .hasAttribute("aria-expanded", "false");

    await click(".styleguide-example__code-toggle");

    assert.dom(".styleguide-example__code").exists();
    assert
      .dom(".styleguide-example__code-toggle")
      .hasAttribute("aria-expanded", "true");

    await click(".styleguide-example__code-toggle");

    assert.dom(".styleguide-example__code").doesNotExist();
  });

  // aria-controls may only name an element that exists, and the panel is unmounted while
  // collapsed, so the attribute has to come and go with it.
  test("aria-controls names the revealed region, and only while it exists", async function (assert) {
    await render(
      <template>
        <StyleguideExample
          @title="Buttons"
          @code={{SOURCE}}
        >demo</StyleguideExample>
      </template>
    );

    assert
      .dom(".styleguide-example__code-toggle")
      .doesNotHaveAttribute("aria-controls");

    await click(".styleguide-example__code-toggle");

    const controls = find(".styleguide-example__code-toggle").getAttribute(
      "aria-controls"
    );

    assert.dom(`#${controls}`).hasClass("styleguide-example__code");
    assert
      .dom(".styleguide-example__code")
      .hasAttribute("role", "region")
      .hasAttribute(
        "aria-label",
        i18n("styleguide.example.code_region", { title: "Buttons" })
      );

    await click(".styleguide-example__code-toggle");

    assert
      .dom(".styleguide-example__code-toggle")
      .doesNotHaveAttribute(
        "aria-controls",
        "the reference goes away with the region it named"
      );
  });

  // The id comes from a module-level counter precisely so two cards on one page do not collide.
  // With a constant id, every toggle would point at the first card's panel and the page would
  // ship duplicate DOM ids.
  test("two cards on a page get distinct region ids", async function (assert) {
    await render(
      <template>
        <StyleguideExample @title="First" @code={{SOURCE}}>a</StyleguideExample>
        <StyleguideExample
          @title="Second"
          @code={{SOURCE}}
        >b</StyleguideExample>
      </template>
    );

    const toggles = findAll(".styleguide-example__code-toggle");
    await click(toggles[0]);
    await click(toggles[1]);

    const ids = findAll(".styleguide-example__code").map((panel) => panel.id);

    assert.strictEqual(ids.length, 2, "both panels are open");
    assert.notStrictEqual(ids[0], ids[1], "the two panels have different ids");

    findAll(".styleguide-example").forEach((card, index) => {
      const controls = card
        .querySelector(".styleguide-example__code-toggle")
        .getAttribute("aria-controls");

      assert.strictEqual(
        controls,
        ids[index],
        `card ${index} points at its own panel`
      );
    });
  });

  test("renders backticked prose as inline code", async function (assert) {
    await render(
      <template>
        <StyleguideExample
          @title="Buttons"
          @description="never mutates `@value`"
        >
          demo
        </StyleguideExample>
      </template>
    );

    assert.dom(".styleguide-example__description code").hasText("@value");
  });

  test("a named block wins over the string arg", async function (assert) {
    await render(
      <template>
        <StyleguideExample @title="Buttons" @description="from the arg">
          <:description><em class="from-block">from the block</em></:description>
          <:default>demo</:default>
        </StyleguideExample>
      </template>
    );

    assert.dom(".styleguide-example__description .from-block").exists();
    assert
      .dom(".styleguide-example__description")
      .doesNotIncludeText("from the arg");
  });

  test("renders the try-this and note slots from string args", async function (assert) {
    await render(
      <template>
        <StyleguideExample
          @title="Buttons"
          @tryThis="Press it twice"
          @note="It counts every press"
        >demo</StyleguideExample>
      </template>
    );

    assert
      .dom(".styleguide-example__try-this")
      .includesText("Press it twice")
      .includesText(i18n("styleguide.example.try_this"));
    assert.dom(".styleguide-example__note").hasText("It counts every press");
  });

  test("try-this and note accept blocks, which win over the args", async function (assert) {
    await render(
      <template>
        <StyleguideExample @title="Buttons" @tryThis="arg try" @note="arg note">
          <:tryThis><em class="block-try">block try</em></:tryThis>
          <:note><ul class="block-note"><li>block note</li></ul></:note>
          <:default>demo</:default>
        </StyleguideExample>
      </template>
    );

    assert.dom(".styleguide-example__try-this .block-try").exists();
    assert.dom(".styleguide-example__try-this").doesNotIncludeText("arg try");
    assert.dom(".styleguide-example__note .block-note").exists();
    assert.dom(".styleguide-example__note").doesNotIncludeText("arg note");
  });

  test("omitted slots render no elements", async function (assert) {
    await render(
      <template>
        <StyleguideExample @title="Buttons">demo</StyleguideExample>
      </template>
    );

    assert.dom(".styleguide-example__description").doesNotExist();
    assert.dom(".styleguide-example__try-this").doesNotExist();
    assert.dom(".styleguide-example__note").doesNotExist();
  });

  test("passes through plain HTML attributes", async function (assert) {
    await render(
      <template>
        <StyleguideExample @title="Buttons" class="--wide" data-flavour="x">
          demo
        </StyleguideExample>
      </template>
    );

    assert.dom(".styleguide-example").hasClass("--wide");
    assert.dom(".styleguide-example").hasAttribute("data-flavour", "x");
  });
});
