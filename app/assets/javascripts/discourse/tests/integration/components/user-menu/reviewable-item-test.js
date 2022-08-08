import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import UserMenuReviewable from "discourse/models/user-menu-reviewable";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import I18n from "I18n";
import UserMenuReviewableItem from "discourse/components/user-menu/reviewable-item";

function getReviewableListItem({
  site,
  siteSettings,
  currentUser,
  overrides = {},
}) {
  const reviewable = UserMenuReviewable.create(
    Object.assign(
      {
        flagger_username: "sayo2",
        id: 17,
        pending: false,
        post_number: 3,
        topic_fancy_title: "anything hello world",
        type: "Reviewable",
      },
      overrides
    )
  );

  return new UserMenuReviewableItem({
    reviewable,
    siteSettings,
    site,
    currentUser,
  });
}

module(
  "Integration | Component | user-menu | reviewable-item",
  function (hooks) {
    setupRenderingTest(hooks);

    const template = hbs`<UserMenu::ItemsListItem @item={{this.item}}/>`;

    test("doesn't push `reviewed` to the classList if the reviewable is pending", async function (assert) {
      this.set(
        "item",
        getReviewableListItem({
          site: this.site,
          siteSettings: this.siteSettings,
          currentUser: this.currentUser,
          overrides: { pending: true },
        })
      );

      await render(template);
      assert.ok(!exists("li.reviewed"));
      assert.ok(exists("li"));
    });

    test("pushes `reviewed` to the classList if the reviewable isn't pending", async function (assert) {
      this.set(
        "item",
        getReviewableListItem({
          site: this.site,
          siteSettings: this.siteSettings,
          currentUser: this.currentUser,
          overrides: { pending: false },
        })
      );

      await render(template);

      assert.ok(exists("li.reviewed"));
    });

    test("has elements for label and description", async function (assert) {
      this.set(
        "item",
        getReviewableListItem({
          site: this.site,
          siteSettings: this.siteSettings,
          currentUser: this.currentUser,
        })
      );

      await render(template);

      const label = query("li .reviewable-label");
      const description = query("li .reviewable-description");

      assert.strictEqual(
        label.textContent.trim(),
        "sayo2",
        "the label is the flagger_username"
      );

      assert.strictEqual(
        description.textContent.trim(),
        I18n.t("user_menu.reviewable.default_item", {
          reviewable_id: this.item.reviewable.id,
        }),
        "displays the description for the reviewable"
      );
    });

    test("the item's label is a placeholder that indicates deleted user if flagger_username is absent", async function (assert) {
      this.set(
        "item",
        getReviewableListItem({
          site: this.site,
          siteSettings: this.siteSettings,
          currentUser: this.currentUser,
          overrides: { flagger_username: null },
        })
      );

      await render(template);

      const label = query("li .reviewable-label");

      assert.strictEqual(
        label.textContent.trim(),
        I18n.t("user_menu.reviewable.deleted_user")
      );
    });
  }
);
