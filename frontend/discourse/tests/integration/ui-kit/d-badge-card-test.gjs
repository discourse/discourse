import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DBadgeCard from "discourse/ui-kit/d-badge-card";

module("Integration | ui-kit | DBadgeCard", function (hooks) {
  setupRenderingTest(hooks);

  test("granted", async function (assert) {
    const badge = { slug: "custombadge" };

    await render(
      <template><DBadgeCard @badge={{badge}} @granted={{true}} /></template>
    );

    assert.dom(".check-display").exists();
    assert
      .dom(".badge-link")
      .hasAttribute(
        "aria-describedby",
        "badge-summary-custombadge badge-awarded-custombadge"
      );
  });

  test("not granted", async function (assert) {
    const badge = { slug: "custombadge" };

    await render(<template><DBadgeCard @badge={{badge}} /></template>);

    assert.dom(".check-display").doesNotExist();
    assert
      .dom(".badge-link")
      .hasAttribute("aria-describedby", "badge-summary-custombadge");
  });

  test("ignores has_badge on the badge itself", async function (assert) {
    const badge = { slug: "custombadge", has_badge: true };

    await render(<template><DBadgeCard @badge={{badge}} /></template>);

    assert
      .dom(".check-display")
      .doesNotExist(
        "the caller says who holds the badge, not the shared record"
      );
  });
});
