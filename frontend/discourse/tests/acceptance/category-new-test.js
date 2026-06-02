import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { CATEGORY_TEXT_COLORS } from "discourse/lib/constants";
import { cloneJSON } from "discourse/lib/object";
import DiscourseURL from "discourse/lib/url";
import { fixturesByUrl } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

acceptance("New category access for moderators", function (needs) {
  needs.user({ moderator: true, admin: false, trust_level: 1 });

  test("Prevents access when moderator cannot create categories", async function (assert) {
    await visit("/new-category");
    assert.strictEqual(currentURL(), "/404");
  });

  test("Authorizes access when moderator can create categories", async function (assert) {
    updateCurrentUser({ can_create_category: true });
    await visit("/new-category");

    assert.strictEqual(
      currentURL(),
      "/new-category/general",
      "it allows access to new category"
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
  needs.user({ can_create_category: true });

  test("Creating a new category", async function (assert) {
    await visit("/new-category");

    assert.dom(".badge-category").exists();
    assert.dom(".category-breadcrumb").doesNotExist();

    await fillIn("input.category-name", "testing");
    assert.dom(".badge-category").hasText("testing");

    if (!document.querySelector(".edit-category-topic-template")) {
      await click(".category-show-advanced-tabs-toggle");
    }

    assert
      .dom(".edit-category-topic-template")
      .exists("it can switch to the topic template tab");

    assert.dom(".edit-category-tags").exists("it can switch to the tags tab");
    await click(".edit-category-tags a");
    await click(".add-required-tag-group");

    await formKit().field("required_tag_groups.0.name").select("TagGroup1");

    await click(".admin-changes-banner .btn-primary");

    assert.strictEqual(
      currentURL(),
      "/c/testing/edit/general",
      "it transitions to the category edit route"
    );

    await visit("/c/testing/edit/tags");

    assert.strictEqual(
      formKit().field("required_tag_groups.0.name").value(),
      "TagGroup1",
      "shows saved required tag group"
    );

    assert.dom(".d-page-header__title").hasText(
      i18n("category.edit_dialog_title", {
        categoryName: "testing",
      })
    );

    await click(".edit-category-security a");
    assert
      .dom(".permission-row button.reply-toggle")
      .exists("it can switch to the security tab");

    await click(".edit-category-settings a");
    assert
      .form()
      .field("search_priority")
      .exists("it can switch to the settings tab");

    sinon.stub(DiscourseURL, "routeTo");
  });

  test("Specifying a parent category", async function (assert) {
    await visit("/new-category");

    await fillIn("input.category-name", "testing");

    const categorySelector = selectKit(".category-chooser");
    await categorySelector.expand();
    await categorySelector.selectRowByValue(6); // 6 is support category's id

    assert
      .dom("input.category-name")
      .hasValue("testing", "it doesn't clear out the rest of the form fields");
    assert.strictEqual(categorySelector.header().value(), "6");
  });
});

acceptance("Category type setup page", function (needs) {
  needs.user({ admin: true, can_create_category: true });
  needs.pretender((server, helper) => {
    server.get("/categories/types", () => {
      return helper.response(200, {
        types: [
          {
            id: "discussion",
            name: "Discussion",
            title: "discussion",
            icon: "comments",
            description: "General discussion",
            configuration_schema: {},
            available: true,
          },
          {
            id: "support",
            name: "Support",
            title: "support",
            icon: "circle-question",
            description: "Q&A support",
            configuration_schema: {},
            available: true,
          },
        ],
        counts: {
          discussion: 1,
          support: 0,
        },
      });
    });
  });

  test("Visiting /new-category redirects to setup page", async function (assert) {
    await visit("/new-category");
    assert.strictEqual(currentURL(), "/new-category/setup");
  });

  test("Setup page shows type cards", async function (assert) {
    await visit("/new-category/setup");
    assert.dom(".category-type-cards__card").exists({ count: 2 });
    assert.dom(".category-type-cards__card-name").exists();
  });

  test("Clicking a type card transitions to new category form", async function (assert) {
    await visit("/new-category/setup");
    await click(
      ".category-type-cards__card:first-child .category-type-cards__card-select"
    );
    assert.strictEqual(currentURL(), "/new-category/general");
  });
});

acceptance("Category text color", function (needs) {
  needs.user({ can_create_category: true });
  needs.pretender((server, helper) => {
    const category = cloneJSON(fixturesByUrl["/c/11/show.json"]).category;

    server.get("/c/testing/find_by_slug.json", () => {
      return helper.response(200, {
        category: {
          ...category,
          color: "EEEEEE",
          text_color: "000000",
        },
      });
    });
  });

  test("Category text color is set based on contrast", async function (assert) {
    await visit("/new-category");
    await click(".category-show-advanced-tabs-toggle");
    await click(".edit-category-images a");

    assert.strictEqual(
      formKit().field("text_color").value(),
      CATEGORY_TEXT_COLORS[0],
      "has the default text color"
    );

    await click(".edit-category-general a");
    await fillIn("input.category-name", "testing");
    await formKit().field("color").fillIn("EEEEEE");
    await click(".edit-category-images a");

    assert.strictEqual(
      formKit().field("text_color").value(),
      CATEGORY_TEXT_COLORS[1],
      "sets the contrast text color"
    );
  });
});

acceptance("New category preview", function (needs) {
  needs.user({ admin: true, can_create_category: true });

  test("Category badge color appears and updates", async function (assert) {
    await visit("/new-category");
    await click(".form-kit__control-radio[value='square']");

    let previewBadgeColor = document
      .querySelector(".edit-category-tab-general .badge-category")
      .style.getPropertyValue("--category-badge-color")
      .trim();

    assert.strictEqual(previewBadgeColor, "#0088CC");

    await formKit().field("color").fillIn("FF00FF");

    previewBadgeColor = document
      .querySelector(".edit-category-tab-general .badge-category")
      .style.getPropertyValue("--category-badge-color")
      .trim();

    assert.strictEqual(previewBadgeColor, "#FF00FF");
  });
});
