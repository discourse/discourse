import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";

module("Integration | Component | AdminConfigAreaCard", function (hooks) {
  hooks.beforeEach(function () {});
  setupRenderingTest(hooks);

  test("renders admin config area card without toggle button", async function (assert) {
    await render(<template>
      <AdminConfigAreaCard @translatedHeading="test heading"><:content
        >test</:content></AdminConfigAreaCard>
    </template>);

    assert.dom(".admin-config-area-card__title").exists();
    assert.dom(".admin-config-area-card__content").exists();
    assert.dom(".admin-config-area-card__toggle-button").doesNotExist();
  });

  test("renders admin config area card with toggle button", async function (assert) {
    await render(<template>
      <AdminConfigAreaCard
        @translatedHeading="test heading"
        @collapsable={{true}}
      ><:content>test</:content></AdminConfigAreaCard>
    </template>);

    assert.dom(".admin-config-area-card__title").exists();
    assert.dom(".admin-config-area-card__content").exists();
    assert.dom(".admin-config-area-card__toggle-button").exists();

    await click(".admin-config-area-card__toggle-button");
    assert.dom(".admin-config-area-card__content").doesNotExist();

    await click(".admin-config-area-card__toggle-button");
    assert.dom(".admin-config-area-card__content").exists();
  });

  test("renders admin config area card with header action", async function (assert) {
    await render(<template>
      <AdminConfigAreaCard
        @translatedHeading="test heading"
        @collapsable={{true}}
      >
        <:headerAction><button>test</button></:headerAction>
        <:content>test</:content></AdminConfigAreaCard>
    </template>);

    assert.dom(".admin-config-area-card__header-action button").exists();
  });
});
