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

  test("ignores has_badge on the badge itself", async function (assert) {
    const badge = { slug: "custombadge", has_badge: true };

    await render(<template><DBadgeCard @badge={{badge}} /></template>);

    assert
      .dom(".check-display")
      .doesNotExist(
        "the caller says who holds the badge, not the shared record"
      );
    assert
      .dom(".badge-link")
      .hasAttribute("aria-describedby", "badge-summary-custombadge");
  });

  test("shows the site-wide grant count without @count", async function (assert) {
    const badge = { slug: "custombadge", grant_count: 1234 };

    await render(<template><DBadgeCard @badge={{badge}} /></template>);

    assert.dom(".badge-granted").hasText("1.2k awarded");
    assert
      .dom(".badge-link")
      .hasAttribute(
        "aria-describedby",
        "badge-summary-custombadge badge-granted-custombadge"
      );
  });

  test("shows the user's own grant count with @count", async function (assert) {
    const badge = { slug: "custombadge", grant_count: 5 };

    await render(
      <template><DBadgeCard @badge={{badge}} @count={{1234}} /></template>
    );

    assert.dom(".badge-granted").hasText("Granted 1.2k times");
  });

  test("hides the grant count when @count is 1", async function (assert) {
    const badge = { slug: "custombadge", grant_count: 5 };

    await render(
      <template><DBadgeCard @badge={{badge}} @count={{1}} /></template>
    );

    assert.dom(".badge-granted").doesNotExist();
    assert
      .dom(".badge-link")
      .hasAttribute("aria-describedby", "badge-summary-custombadge");
  });

  test("links to the user-filtered badge page with @filterUser", async function (assert) {
    const badge = { slug: "custombadge", url: "/badges/1/custombadge" };

    await render(
      <template>
        <DBadgeCard @badge={{badge}} @filterUser={{true}} @username="bob" />
      </template>
    );

    assert
      .dom(".badge-link")
      .hasAttribute("href", "/badges/1/custombadge?username=bob");
  });
});
