import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AdminConfigAreaCardSection from "admin/components/admin-config-area-card-section";

module(
  "Integration | Component | AdminConfigAreaCardSection",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders admin config area card section without toggle icon", async function (assert) {
      await render(
        <template>
          <AdminConfigAreaCardSection @heading="test heading"><:content
            >test</:content></AdminConfigAreaCardSection>
        </template>
      );

      assert
        .dom(".admin-config-area-card-section__title")
        .hasText("test heading");
      assert.dom(".admin-config-area-card-section__content").exists();
      assert
        .dom(".admin-config-area-card-section__header-wrapper.collapsable")
        .doesNotExist();
      assert
        .dom(".admin-config-area-card-section__header-wrapper svg")
        .doesNotExist();
    });

    test("renders admin config area card section with toggle icon", async function (assert) {
      await render(
        <template>
          <AdminConfigAreaCardSection
            @heading="test heading"
            @collapsable={{true}}
          ><:content>test</:content></AdminConfigAreaCardSection>
        </template>
      );

      assert
        .dom(".admin-config-area-card-section__title")
        .hasText("test heading");
      assert.dom(".admin-config-area-card-section__content").hasText("test");
      assert
        .dom(".admin-config-area-card-section__header-wrapper svg")
        .exists();
      assert
        .dom(".admin-config-area-card-section__header-wrapper.collapsable")
        .exists();

      await click(
        ".admin-config-area-card-section__header-wrapper.collapsable"
      );
      assert.dom(".admin-config-area-card-section__content").doesNotExist();

      await click(
        ".admin-config-area-card-section__header-wrapper.collapsable"
      );
      assert.dom(".admin-config-area-card-section__content").exists();
    });

    test("renders admin config area card section with toggle icon and collapsed by default", async function (assert) {
      await render(
        <template>
          <AdminConfigAreaCardSection
            @heading="test heading"
            @collapsable={{true}}
            @collapsed={{true}}
          ><:content>test</:content></AdminConfigAreaCardSection>
        </template>
      );

      assert.dom(".admin-config-area-card-section__title").exists();
      assert
        .dom(".admin-config-area-card-section__header-wrapper svg")
        .exists();
      assert.dom(".admin-config-area-card-section__content").doesNotExist();
    });
  }
);
