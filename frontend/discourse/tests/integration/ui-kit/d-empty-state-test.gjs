import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DEmptyState from "discourse/ui-kit/d-empty-state";

module("Integration | ui-kit | DEmptyState", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders", async function (assert) {
    await render(
      <template>
        <DEmptyState @title="user.no_bookmarks_title" @body="body" />
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
      <template><DEmptyState @title="title" @icon="table-columns" /></template>
    );

    assert.dom(".empty-state__image.--icon .d-icon-table-columns").exists();
    assert
      .dom(".empty-state__container")
      .hasClass("--with-image", "an icon counts as the image slot");
  });

  test("@svgContent wins over @icon", async function (assert) {
    await render(
      <template>
        <DEmptyState @title="title" @icon="table-columns" @svgContent="art" />
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
        <DEmptyState @title="title" class="extra" data-test-thing="yes" />
      </template>
    );

    assert.dom(".empty-state__container").hasClass("extra");
    assert
      .dom(".empty-state__container")
      .hasAttribute("data-test-thing", "yes");
  });
});
