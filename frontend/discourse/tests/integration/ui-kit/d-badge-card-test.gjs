import { click, render } from "@ember/test-helpers";
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

  test("a large card shows the long description without a link", async function (assert) {
    const badge = {
      slug: "custombadge",
      name: "Custom",
      description: "Short",
      long_description: "Much longer",
    };

    await render(
      <template><DBadgeCard @badge={{badge}} @size="large" /></template>
    );

    assert.dom(".badge-card").hasClass("--badge-large");
    assert.dom(".badge-summary").hasText("Much longer");
    assert.dom(".badge-link").doesNotExist("the name is not a link");
  });

  test("a medium card shows the description", async function (assert) {
    const badge = {
      slug: "custombadge",
      description: "Short",
      long_description: "Much longer",
    };

    await render(<template><DBadgeCard @badge={{badge}} /></template>);

    assert.dom(".badge-card").hasClass("--badge-medium");
    assert.dom(".badge-summary").hasText("Short");
  });

  test("@canFavorite offers to favorite the badge", async function (assert) {
    const badge = { slug: "custombadge" };
    let favorited = false;
    const onFavoriteClick = () => (favorited = true);

    await render(
      <template>
        <DBadgeCard
          @badge={{badge}}
          @canFavorite={{true}}
          @canFavoriteMoreBadges={{true}}
          @onFavoriteClick={{onFavoriteClick}}
        />
        <DBadgeCard
          @badge={{badge}}
          @canFavorite={{true}}
          @canFavoriteMoreBadges={{false}}
        />
      </template>
    );

    assert.dom(".badge-card.--can-favorite").exists({ count: 2 });
    assert
      .dom(":nth-child(1 of .badge-card) .favorite-btn")
      .isNotDisabled()
      .hasAttribute("title", /./, "the button explains itself");
    assert
      .dom(":nth-child(2 of .badge-card) .favorite-btn")
      .isDisabled("no more badges can be favorited");

    await click(":nth-child(1 of .badge-card) .favorite-btn");
    assert.true(favorited, "@onFavoriteClick is called");
  });
});
