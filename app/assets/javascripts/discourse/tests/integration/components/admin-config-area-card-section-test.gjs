import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AdminConfigAreaCardSection from "admin/components/admin-config-area-card-section";

module(
  "Integration | Component | AdminConfigAreaCardSection",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders admin config area card section without toggle button", async function (assert) {
      await render(<template>
        <AdminConfigAreaCardSection @translatedHeading="test heading"><:content
          >test</:content></AdminConfigAreaCardSection>
      </template>);

      assert.dom(".admin-config-area-card-section__title").exists();
      assert.dom(".admin-config-area-card-section__content").exists();
      assert
        .dom(".admin-config-area-card-section__toggle-button")
        .doesNotExist();
    });

    test("renders admin config area card section with toggle button", async function (assert) {
      await render(<template>
        <AdminConfigAreaCardSection
          @translatedHeading="test heading"
          @collapsable={{true}}
        ><:content>test</:content></AdminConfigAreaCardSection>
      </template>);

      assert.dom(".admin-config-area-card-section__title").exists();
      assert.dom(".admin-config-area-card-section__content").exists();
      assert.dom(".admin-config-area-card-section__toggle-button").exists();

      await click(".admin-config-area-card-section__toggle-button");
      assert.dom(".admin-config-area-card-section__content").doesNotExist();

      await click(".admin-config-area-card-section__toggle-button");
      assert.dom(".admin-config-area-card-section__content").exists();
    });

    test("renders admin config area card section with toggle button and collapsed by default", async function (assert) {
      await render(<template>
        <AdminConfigAreaCardSection
          @translatedHeading="test heading"
          @collapsable={{true}}
          @collapsed={{true}}
        ><:content>test</:content></AdminConfigAreaCardSection>
      </template>);

      assert.dom(".admin-config-area-card-section__title").exists();
      assert.dom(".admin-config-area-card-section__toggle-button").exists();
      assert.dom(".admin-config-area-card-section__content").doesNotExist();
    });
  }
);
