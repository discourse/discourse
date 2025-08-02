import { render, settled } from "@ember/test-helpers";
import { setupRenderingTest } from "ember-qunit";
import { module, test } from "qunit";
import { ExtraNavItem } from "discourse/models/nav-item";

module("Unit | Model | extra-nav-item", function (hooks) {
  setupRenderingTest(hooks);

  test("displayName updates when count property changes", async function (assert) {
    const extraNavItem = ExtraNavItem.create({
      name: "something",
    });

    await render(
      <template>
        <p>{{extraNavItem.displayName}}</p>
      </template>
    );

    assert.dom("p").hasText("[en.filters.something.title count=0]");

    extraNavItem.count = 2;

    await settled();

    assert.dom("p").hasText("[en.filters.something.title_with_count count=2]");
  });
});
