import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { count, exists, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import { NotificationLevels } from "discourse/lib/notification-levels";

const topCategoryIds = [2, 3, 1];
let mutedCategoryIds = [];
let unreadCategoryIds = [];
let categoriesByCount = [];

module("Integration | Component | Widget | hamburger-menu", function (hooks) {
  setupRenderingTest(hooks);

  test("prioritize faq", async function (assert) {
    this.siteSettings.faq_url = "http://example.com/faq";
    this.currentUser.set("read_faq", false);

    await render(hbs`<MountWidget @widget="hamburger-menu" />`);

    assert.ok(exists(".faq-priority"));
    assert.ok(!exists(".faq-link"));
  });

  test("prioritize faq - user has read", async function (assert) {
    this.siteSettings.faq_url = "http://example.com/faq";
    this.currentUser.set("read_faq", true);

    await render(hbs`<MountWidget @widget="hamburger-menu" />`);

    assert.ok(!exists(".faq-priority"));
    assert.ok(exists(".faq-link"));
  });

  test("staff menu - not staff", async function (assert) {
    this.currentUser.setProperties({ admin: false, moderator: false });

    await render(hbs`<MountWidget @widget="hamburger-menu" />`);

    assert.ok(!exists(".admin-link"));
  });

  test("staff menu - moderator", async function (assert) {
    this.currentUser.set("moderator", true);
    this.currentUser.set("can_review", true);

    await render(hbs`<MountWidget @widget="hamburger-menu" />`);

    assert.ok(exists(".admin-link"));
    assert.ok(exists(".review"));
    assert.ok(!exists(".settings-link"));
  });

  test("staff menu - admin", async function (assert) {
    this.currentUser.setProperties({ admin: true });

    await render(hbs`<MountWidget @widget="hamburger-menu" />`);

    assert.ok(exists(".settings-link"));
  });

  test("logged in links", async function (assert) {
    await render(hbs`<MountWidget @widget="hamburger-menu" />`);

    assert.ok(exists(".new-topics-link"));
    assert.ok(exists(".unread-topics-link"));
  });

  test("general links", async function (assert) {
    this.owner.unregister("service:current-user");

    await render(hbs`<MountWidget @widget="hamburger-menu" />`);

    assert.ok(!exists("li[class='']"));
    assert.ok(exists(".latest-topics-link"));
    assert.ok(!exists(".new-topics-link"));
    assert.ok(!exists(".unread-topics-link"));
    assert.ok(exists(".top-topics-link"));
    assert.ok(exists(".badge-link"));
    assert.ok(exists(".category-link"));
    assert.ok(exists(".about-link"));
    assert.ok(exists(".keyboard-shortcuts-link"));
  });

  let maxCategoriesToDisplay;

  test("top categories - anonymous", async function (assert) {
    this.owner.unregister("service:current-user");
    this.siteSettings.header_dropdown_category_count = 8;

    await render(hbs`<MountWidget @widget="hamburger-menu" />`);

    assert.strictEqual(count(".category-link"), 8);
    assert.deepEqual(
      [...queryAll(".category-link .category-name")].map((el) => el.innerText),
      this.site
        .get("categoriesByCount")
        .reject((c) => c.id === this.site.uncategorized_category_id)
        .slice(0, 8)
        .map((c) => c.name)
    );
  });

  test("top categories - allow_uncategorized_topics", async function (assert) {
    this.owner.unregister("service:current-user");
    this.siteSettings.allow_uncategorized_topics = true;
    this.siteSettings.header_dropdown_category_count = 8;

    await render(hbs`<MountWidget @widget="hamburger-menu" />`);

    assert.strictEqual(count(".category-link"), 8);
    assert.deepEqual(
      [...queryAll(".category-link .category-name")].map((el) => el.innerText),
      this.site
        .get("categoriesByCount")
        .slice(0, 8)
        .map((c) => c.name)
    );
  });

  test("top categories", async function (assert) {
    this.siteSettings.header_dropdown_category_count = 8;
    maxCategoriesToDisplay = this.siteSettings.header_dropdown_category_count;
    categoriesByCount = this.site
      .get("categoriesByCount")
      .reject((c) => c.id === this.site.uncategorized_category_id)
      .slice();
    categoriesByCount.every((c) => {
      if (!topCategoryIds.includes(c.id)) {
        if (mutedCategoryIds.length === 0) {
          mutedCategoryIds.push(c.id);
          c.set("notification_level", NotificationLevels.MUTED);
        } else if (unreadCategoryIds.length === 0) {
          unreadCategoryIds.push(c.id);
          for (let i = 0; i < 5; i++) {
            c.topicTrackingState.modifyState(123 + i, {
              category_id: c.id,
              last_read_post_number: 1,
              highest_post_number: 2,
              notification_level: NotificationLevels.TRACKING,
            });
          }
        } else {
          unreadCategoryIds.splice(0, 0, c.id);
          for (let i = 0; i < 10; i++) {
            c.topicTrackingState.modifyState(321 + i, {
              category_id: c.id,
              last_read_post_number: null,
              created_in_new_period: true,
            });
          }
          return false;
        }
      }
      return true;
    });
    this.currentUser.set("top_category_ids", topCategoryIds);

    await render(hbs`<MountWidget @widget="hamburger-menu" />`);

    assert.strictEqual(
      count(".category-link"),
      maxCategoriesToDisplay,
      "categories displayed limited by header_dropdown_category_count"
    );

    categoriesByCount = categoriesByCount.filter(
      (c) => !mutedCategoryIds.includes(c.id)
    );
    let ids = [
      ...unreadCategoryIds,
      ...topCategoryIds,
      ...categoriesByCount.map((c) => c.id),
    ]
      .uniq()
      .slice(0, maxCategoriesToDisplay);

    assert.deepEqual(
      [...queryAll(".category-link .category-name")].map((el) => el.innerText),
      ids.map(
        (id) => categoriesByCount.find((category) => category.id === id).name
      ),
      "top categories are in the correct order"
    );
  });

  test("badges link - disabled", async function (assert) {
    this.siteSettings.enable_badges = false;

    await render(hbs`<MountWidget @widget="hamburger-menu" />`);

    assert.ok(!exists(".badge-link"));
  });

  test("badges link", async function (assert) {
    await render(hbs`<MountWidget @widget="hamburger-menu" />`);

    assert.ok(exists(".badge-link"));
  });

  test("user directory link", async function (assert) {
    await render(hbs`<MountWidget @widget="hamburger-menu" />`);

    assert.ok(exists(".user-directory-link"));
  });

  test("user directory link - disabled", async function (assert) {
    this.siteSettings.enable_user_directory = false;

    await render(hbs`<MountWidget @widget="hamburger-menu" />`);

    assert.ok(!exists(".user-directory-link"));
  });
});
