import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const DummyTabComponent = <template>
  {{#if (eq @selectedTab "custom-test")}}
    <div class="custom-test-tab-content">Custom tab content</div>
  {{/if}}
</template>;

import { eq } from "discourse/truth-helpers";

acceptance("Edit Category - Plugin Tab API", function (needs) {
  needs.user();
  needs.settings({ enable_simplified_category_creation: true });

  test("registerEditCategoryTab adds a tab that renders", async function (assert) {
    withPluginApi((api) => {
      api.registerEditCategoryTab({
        id: "custom-test",
        name: "Custom Test",
        component: DummyTabComponent,
      });
    });

    await visit("/c/bug/edit/custom-test");

    assert
      .dom(".edit-category-custom-test")
      .exists("the plugin tab is rendered in the nav");
    assert
      .dom(".edit-category-custom-test a")
      .hasText("Custom Test", "the tab has the correct title");
    assert
      .dom(".custom-test-tab-content")
      .exists("the plugin tab component is rendered");
  });

  test("registerEditCategoryTab respects condition", async function (assert) {
    withPluginApi((api) => {
      api.registerEditCategoryTab({
        id: "hidden-tab",
        name: "Hidden Tab",
        component: DummyTabComponent,
        condition: () => false,
      });
    });

    await visit("/c/bug/edit/general");

    assert
      .dom(".edit-category-hidden-tab")
      .doesNotExist("the tab is not shown when condition returns false");
  });
});
