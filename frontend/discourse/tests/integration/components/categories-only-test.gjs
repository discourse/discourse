import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import CategoriesOnly from "discourse/components/categories-only";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | CategoriesOnly", function (hooks) {
  setupRenderingTest(hooks);

  test("toggles the muted categories", async function (assert) {
    const store = this.owner.lookup("service:store");
    const categories = [
      store.createRecord("category", { id: 1, name: "Visible", slug: "v" }),
      store.createRecord("category", {
        id: 2,
        name: "Muted",
        slug: "m",
        notification_level: NotificationLevels.MUTED,
      }),
    ];

    await render(
      <template><CategoriesOnly @categories={{categories}} /></template>
    );

    assert
      .dom(".muted-categories .category-list")
      .hasClass("hidden", "starts with muted categories collapsed");

    await click(".muted-categories-link");

    assert
      .dom(".muted-categories .category-list")
      .doesNotHaveClass("hidden", "expands the muted categories");
  });
});
