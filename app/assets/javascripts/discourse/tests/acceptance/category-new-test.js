import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";
import sinon from "sinon";
import { test } from "qunit";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("New category access for moderators", function (needs) {
  needs.user({ moderator: true, admin: false, trust_level: 1 });

  test("Authorizes access based on site setting", async function (assert) {
    this.siteSettings.moderators_manage_categories_and_groups = false;
    await visit("/new-category");

    assert.strictEqual(currentURL(), "/404");

    this.siteSettings.moderators_manage_categories_and_groups = true;
    await visit("/new-category");

    assert.strictEqual(
      currentURL(),
      "/new-category",
      "it allows access to new category when site setting is enabled"
    );
  });
});

acceptance("New category access for non authorized users", function () {
  test("Prevents access when not signed in", async function (assert) {
    await visit("/new-category");
    assert.strictEqual(currentURL(), "/404");
  });
});

acceptance("Category New", function (needs) {
  needs.user();

  test("Creating a new category", async function (assert) {
    await visit("/new-category");

    assert.ok(exists(".badge-category"));
    assert.notOk(exists(".category-breadcrumb"));

    await fillIn("input.category-name", "testing");
    assert.strictEqual(query(".badge-category").innerText, "testing");

    await click(".edit-category-nav .edit-category-topic-template a");
    assert
      .dom(".edit-category-tab-topic-template")
      .isVisible("it can switch to topic template tab");

    await click(".edit-category-nav .edit-category-tags a");
    await click("button.add-required-tag-group");

    const tagSelector = selectKit(
      ".required-tag-group-row .select-kit.tag-group-chooser"
    );
    await tagSelector.expand();
    await tagSelector.selectRowByValue("TagGroup1");

    await click("#save-category");

    assert.strictEqual(
      currentURL(),
      "/c/testing/edit/general",
      "it transitions to the category edit route"
    );

    await click(".edit-category-nav .edit-category-tags a");

    assert.ok(
      exists(
        ".required-tag-group-row .select-kit-header[data-value='TagGroup1']"
      ),
      "it shows saved required tag group"
    );

    assert.strictEqual(
      query(".edit-category-title h2").innerText,
      I18n.t("category.edit_dialog_title", {
        categoryName: "testing",
      })
    );

    await click(".edit-category-security a");
    assert.ok(
      exists(".permission-row button.reply-toggle"),
      "it can switch to the security tab"
    );

    await click(".edit-category-settings a");
    assert.ok(
      exists("#category-search-priority"),
      "it can switch to the settings tab"
    );

    sinon.stub(DiscourseURL, "routeTo");

    await click(".category-back");
    assert.ok(
      DiscourseURL.routeTo.calledWith("/c/testing/11"),
      "back routing works"
    );
  });
});
