import { tracked } from "@glimmer/tracking";
import { render, rerender } from "@ember/test-helpers";
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
    const state = new (class {
      @tracked extra = "first";
      @tracked icon = "gear";
    })();

    await render(
      <template>
        <DEmptyState
          class={{state.extra}}
          role="status"
          @icon={{state.icon}}
          @identifier="probe"
          @title="Empty"
        />
      </template>
    );

    assert.dom(".empty-state__container").hasClass("--probe");
    assert.dom(".empty-state__container").hasClass("--with-image");

    state.extra = "second";
    state.icon = null;
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
});
