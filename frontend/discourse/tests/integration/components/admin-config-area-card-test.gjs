import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | AdminConfigAreaCard", function (hooks) {
  setupRenderingTest(hooks);

  test("renders admin config area card without toggle button", async function (assert) {
    await render(
      <template>
        <AdminConfigAreaCard @translatedHeading="test heading"><:content
          >test</:content></AdminConfigAreaCard>
      </template>
    );

    assert.dom(".admin-config-area-card__title").exists();
    assert.dom(".admin-config-area-card__content").exists();
    assert.dom(".admin-config-area-card__toggle-button").doesNotExist();
  });

  test("renders admin config area card with toggle button", async function (assert) {
    await render(
      <template>
        <AdminConfigAreaCard
          @collapsable={{true}}
          @translatedHeading="test heading"
        ><:content>test</:content></AdminConfigAreaCard>
      </template>
    );

    assert.dom(".admin-config-area-card__title").exists();
    assert.dom(".admin-config-area-card__content").exists();
    assert.dom(".admin-config-area-card__toggle-button").exists();

    await click(".admin-config-area-card__toggle-button");
    assert.dom(".admin-config-area-card__content").doesNotExist();

    await click(".admin-config-area-card__toggle-button");
    assert.dom(".admin-config-area-card__content").exists();
  });

  test("renders admin config area card with toggle button and collapsed by default", async function (assert) {
    await render(
      <template>
        <AdminConfigAreaCard
          @collapsable={{true}}
          @collapsed={{true}}
          @translatedHeading="test heading"
        ><:content>test</:content></AdminConfigAreaCard>
      </template>
    );

    assert.dom(".admin-config-area-card__title").exists();
    assert.dom(".admin-config-area-card__toggle-button").exists();
    assert.dom(".admin-config-area-card__content").doesNotExist();
  });

  test("toggles collapsed content from the title", async function (assert) {
    await render(
      <template>
        <AdminConfigAreaCard
          @collapsable={{true}}
          @collapsed={{true}}
          @translatedHeading="Advanced: workflows"
        ><:content>Workflow details</:content></AdminConfigAreaCard>
      </template>
    );

    assert
      .dom(".admin-config-area-card__title-toggle")
      .hasAttribute("aria-expanded", "false", "starts collapsed");
    await click(".admin-config-area-card__title-toggle");
    assert
      .dom(".admin-config-area-card__content")
      .exists("title expands the content");
    assert
      .dom(".admin-config-area-card__title-toggle")
      .hasAttribute("aria-expanded", "true", "announces expanded state");
    await click(".admin-config-area-card__title-toggle");
    assert
      .dom(".admin-config-area-card__content")
      .doesNotExist("title collapses the content");
  });

  test("renders admin config area card with header action", async function (assert) {
    await render(
      <template>
        <AdminConfigAreaCard
          @collapsable={{true}}
          @translatedHeading="test heading"
        >
          <:headerAction><button>test</button></:headerAction>
          <:content>test</:content></AdminConfigAreaCard>
      </template>
    );

    assert.dom(".admin-config-area-card__header-action button").exists();
  });
});
