import { tracked } from "@glimmer/tracking";
import { trustHTML } from "@ember/template";
import { click, render, rerender } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DEmptyState from "discourse/ui-kit/d-empty-state";

module("Integration | ui-kit | DEmptyState", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders", async function (assert) {
    await render(
      <template>
        <DEmptyState @body="body" @title="user.no_bookmarks_title" />
      </template>
    );

    assert.dom("[data-test-title]").exists();
    assert.dom("[data-test-body]").exists();
  });

  test("text-only without an image or an icon", async function (assert) {
    await render(<template><DEmptyState @title="title" /></template>);

    assert.dom(".empty-state__container").hasClass("--text-only");
    assert.dom(".empty-state__image").doesNotExist();
  });

  test("@icon renders an icon in place of an illustration", async function (assert) {
    await render(
      <template><DEmptyState @icon="table-columns" @title="title" /></template>
    );

    assert.dom(".empty-state__image.--icon .d-icon-table-columns").exists();
    assert
      .dom(".empty-state__container")
      .hasClass("--with-image", "an icon counts as the image slot");
  });

  test("@svgContent wins over @icon", async function (assert) {
    await render(
      <template>
        <DEmptyState @icon="table-columns" @svgContent="art" @title="title" />
      </template>
    );

    assert.dom(".empty-state__image").hasText("art");
    assert
      .dom(".empty-state__image .d-icon-table-columns")
      .doesNotExist("the icon does not render alongside the illustration");
  });

  test("@svgContent renders a component", async function (assert) {
    const Art = <template>
      <svg class="test-art-component"></svg>
    </template>;

    await render(<template><DEmptyState @svgContent={{Art}} /></template>);

    assert
      .dom(".empty-state__image svg.test-art-component")
      .exists("the component is rendered");
  });

  test("@svgContent renders trusted markup", async function (assert) {
    const art = trustHTML('<svg class="test-art-markup"></svg>');

    await render(<template><DEmptyState @svgContent={{art}} /></template>);

    assert
      .dom(".empty-state__image svg.test-art-markup")
      .exists("the markup is rendered");
  });

  test("@svgContent escapes a plain string", async function (assert) {
    await render(
      <template>
        <DEmptyState @svgContent="<b>art</b>" />
      </template>
    );

    assert
      .dom(".empty-state__image")
      .hasText("<b>art</b>", "the string is shown as text");
    assert
      .dom(".empty-state__image b")
      .doesNotExist("the string is not parsed as markup");
  });

  test("attributes reach the container", async function (assert) {
    await render(
      <template>
        <DEmptyState class="extra" data-test-thing="yes" @title="title" />
      </template>
    );

    assert.dom(".empty-state__container").hasClass("extra");
    assert
      .dom(".empty-state__container")
      .hasAttribute("data-test-thing", "yes");
  });

  test("dynamic classes and @icon update without dropping its own classes", async function (assert) {
    const extra = tracked("first");
    const icon = tracked("gear");

    await render(
      <template>
        <DEmptyState
          class={{extra.value}}
          role="status"
          @icon={{icon.value}}
          @identifier="probe"
          @title="Empty"
        />
      </template>
    );

    assert.dom(".empty-state__container").hasClass("--probe");
    assert.dom(".empty-state__container").hasClass("--with-image");

    extra.value = "second";
    icon.value = null;
    await rerender();

    assert
      .dom(".empty-state__container")
      .hasClass("second")
      .doesNotHaveClass("first")
      .hasClass("--probe")
      .hasClass("--text-only")
      .doesNotHaveClass("--with-image")
      .hasAttribute("role", "status");
    assert.dom(".empty-state__image").doesNotExist();
  });

  test("@ctaDisabled", async function (assert) {
    await render(
      <template>
        <DEmptyState @ctaDisabled={{true}} @ctaLabel="Show all" />
      </template>
    );

    assert.dom(".empty-state__cta .btn").isDisabled();
  });

  test("renders a call to action", async function (assert) {
    let clicked = 0;
    const onCta = () => clicked++;

    await render(
      <template>
        <DEmptyState @ctaAction={{onCta}} @ctaIcon="plus" @ctaLabel="Create" />
      </template>
    );

    assert
      .dom(".empty-state__cta .btn-primary")
      .hasText("Create", "@ctaLabel labels the button");
    assert
      .dom(".empty-state__cta .btn-primary .d-icon-plus")
      .exists("@ctaIcon is shown");

    await click(".empty-state__cta .btn-primary");
    assert.strictEqual(clicked, 1, "@ctaAction is called on click");
  });

  test("renders a tip from @tipText", async function (assert) {
    await render(
      <template>
        <DEmptyState @tipIcon="circle-info" @tipText="Try a search" />
      </template>
    );

    assert
      .dom(".empty-state__tip")
      .hasText("Try a search", "@tipText is shown");
    assert
      .dom(".empty-state__tip .d-icon-circle-info")
      .exists("@tipIcon is shown");
  });

  test("the tip block wins over @tipText", async function (assert) {
    await render(
      <template>
        <DEmptyState @tipText="ignored">
          <:tip><span class="custom-tip">Custom</span></:tip>
        </DEmptyState>
      </template>
    );

    assert
      .dom(".empty-state__tip .custom-tip")
      .exists("the tip block is rendered");
    assert
      .dom(".empty-state__tip")
      .doesNotIncludeText("ignored", "the block wins over @tipText");
  });
});
