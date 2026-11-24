import {
  blur,
  click,
  currentURL,
  fillIn,
  find,
  settled,
  triggerEvent,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { CATEGORY_TEXT_COLORS } from "discourse/lib/constants";
import { cloneJSON } from "discourse/lib/object";
import DiscourseURL from "discourse/lib/url";
import pretender, {
  fixturesByUrl,
  response,
} from "discourse/tests/helpers/create-pretender";
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

    assert.dom(".category-style-trigger").exists();
    assert.dom(".category-breadcrumb").doesNotExist();

    await fillIn("input.category-name", "testing");
    assert.dom("input.category-name").hasValue("testing");

    await click(".category-show-advanced-tabs-toggle");

    assert
      .dom(".edit-category-topic-template")
      .exists("it can switch to the topic template tab");

    assert.dom(".edit-category-tags").exists("it can switch to the tags tab");
    await click(".edit-category-tags a");
    await click(".add-required-tag-group");

    await formKit().field("required_tag_groups.0.name").select("TagGroup1");

    await click(".d-floating-control-bar .btn-primary");

    assert.strictEqual(
      currentURL(),
      "/c/testing/11",
      "it transitions to the new category's page"
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
  });

  test("Keeps the save button busy while redirecting to the new category", async function (assert) {
    const category = cloneJSON(fixturesByUrl["/c/11/show.json"]).category;
    category.category_types.support = category.available_category_types[0];
    pretender.post("/categories", () => response({ category }));
    const redirectAbsolute = sinon.stub(DiscourseURL, "redirectAbsolute");

    await visit("/new-category");
    await fillIn("input.category-name", "testing");
    await click("#save-category");
    document.querySelector("#save-category").click();
    await settled();

    assert.true(redirectAbsolute.calledWith("/c/testing/11"));
    assert.dom("#save-category").isDisabled();
    assert.strictEqual(
      pretender.handledRequests.filter(
        ({ method, url }) => method === "POST" && url === "/categories"
      ).length,
      1
    );
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

  test("Picking a type card on the setup page opens the new category form", async function (assert) {
    await visit("/new-category");
    assert.strictEqual(currentURL(), "/new-category/setup");
    assert.dom(".category-type-cards__card").exists({ count: 2 });
    assert.dom(".category-type-cards__card-name").exists();

    await click(
      ".category-type-cards__card:first-child .category-type-cards__card-select"
    );
    assert.strictEqual(currentURL(), "/new-category/general");
  });
});

acceptance("Category color", function (needs) {
  needs.user({ can_create_category: true });

  needs.pretender((server, helper) => {
    server.get("/svg-sprite/picker-search", () =>
      helper.response({ icons: [{ id: "anchor" }], has_more: false })
    );
  });

  function previewColor() {
    return getComputedStyle(find(".category-name-style__preview"))
      .getPropertyValue("--icon-color")
      .trim();
  }

  test("Badge preview follows the color and text color follows its contrast", async function (assert) {
    await visit("/new-category");
    await click(".category-style-trigger");
    await click("[data-d-tab='square']");
    assert.strictEqual(previewColor(), "#0088CC");
    await click(".category-style-trigger");

    await click(".category-show-advanced-tabs-toggle");
    await click(".edit-category-images a");
    assert.strictEqual(
      formKit().field("text_color").value(),
      CATEGORY_TEXT_COLORS[0],
      "has the default text color"
    );

    await click(".edit-category-general a");
    await click(".category-style-trigger");
    await fillIn(".category-style-content input[name=color]", "0F0");
    assert.strictEqual(previewColor(), "#00FF00");
    await click(".category-style-trigger");

    await click(".edit-category-images a");
    assert.strictEqual(
      formKit().field("text_color").value(),
      CATEGORY_TEXT_COLORS[1],
      "sets the contrast text color"
    );
  });

  test("selects an icon and changes its color in one visit to the picker", async function (assert) {
    await visit("/new-category");
    await fillIn("input.category-name", "Harbor");
    await click(".category-style-trigger");
    await click(".category-style-content [data-icon-id='anchor']");

    assert
      .dom(".category-style-trigger .d-icon-anchor")
      .exists("previews the selected icon");
    await fillIn(".category-style-content input[name=color]", "245A73");
    assert.strictEqual(previewColor(), "#245A73", "previews the new color");
    await triggerEvent("input.category-name", "pointerdown");
    assert
      .dom(".category-style-content")
      .doesNotExist("clicking outside closes the picker");
    assert.dom("input.category-name").hasValue("Harbor");
    await click("#save-category");
    const request = pretender.handledRequests.findLast(
      ({ method, url }) => method === "POST" && url === "/categories"
    );
    const { name, icon, color, style_type } = JSON.parse(request.requestBody);
    assert.deepEqual(
      { name, icon, color, style_type },
      { name: "Harbor", icon: "anchor", color: "245A73", style_type: "icon" }
    );
  });

  test("validates hex on blur and after the picker closes", async function (assert) {
    await visit("/new-category");
    await fillIn("input.category-name", "Harbor");
    await click(".category-style-trigger");
    await click("[data-d-tab='square']");

    const hex = ".category-style-content input[name=color]";
    const inlineError = ".category-name-style__color .form-kit__errors";
    const rowError = "#control-style_type .form-kit__errors";
    const invalidHex = i18n("category.color_validations.non_hexdecimal");
    const fallbackColor = find(hex).value;
    await fillIn(hex, "ABZ");
    assert.dom(inlineError).doesNotExist("waits for the user to finish typing");
    assert.dom(hex).doesNotHaveAttribute("aria-invalid");
    await blur(hex);
    assert.dom(inlineError).hasText(invalidHex);
    assert.dom(hex).hasAria("describedby", find(inlineError).id);
    assert.dom(hex).hasAria("invalid", "true");
    await click(".category-style-trigger");
    await click("#save-category");
    assert.dom(rowError).hasText(invalidHex);

    await click(".category-style-trigger");
    await fillIn(hex, "A");
    assert
      .dom(rowError)
      .hasText(invalidHex, "keeps the submitted message stable while editing");
    await blur(hex);
    assert
      .dom(rowError)
      .hasText(i18n("category.color_validations.incorrect_length"));
    await fillIn(hex, "");
    assert
      .dom(inlineError)
      .doesNotExist("quietly allows replacing the entire value");
    await blur(hex);
    assert
      .dom(hex)
      .hasValue(fallbackColor, "restores the fallback when left empty");
    assert.dom(inlineError).doesNotExist();
    assert.dom(rowError).doesNotExist();
    assert.dom(hex).doesNotHaveAttribute("aria-invalid");
  });

  test("shows the color error in the hex prefix on both style tabs", async function (assert) {
    await visit("/new-category");
    await click(".category-style-trigger");
    const hex = ".category-style-content input[name=color]";
    const prefix =
      ".category-style-content .form-kit__control-color-input-prefix";
    const message = i18n("category.color_validations.non_hexdecimal");

    for (const tab of ["icon", "square"]) {
      await click(`[data-d-tab='${tab}']`);
      await fillIn(hex, "AB");
      assert
        .dom(prefix)
        .hasText("#", `${tab} keeps the prefix while typing a partial color`);
      await fillIn(hex, "AB1C2D");
      await blur(hex);
      assert.dom(prefix).hasText("#", `${tab} accepts the completed color`);
      await fillIn(hex, "ABZ");
      await blur(hex);
      assert
        .dom(`${prefix} button`)
        .hasAria("label", message, `${tab} names the warning`);
      await click(`${prefix} button`);
      assert
        .dom("[role='tooltip']")
        .hasText(message, `${tab} explains the error`);
      await fillIn(hex, "ABC");
      assert
        .dom(prefix)
        .hasText("#", `${tab} restores the prefix when the color is valid`);
      assert
        .dom("[role='tooltip']")
        .doesNotExist(`${tab} dismisses the warning`);
    }
  });

  test("switching from Emoji to Square clears a submitted emoji error", async function (assert) {
    await visit("/new-category");
    await fillIn("input.category-name", "Harbor");
    await click(".category-style-trigger");
    await click("[data-d-tab='emoji']");
    await click(".category-style-trigger");
    await click("#save-category");

    const error = "#control-style_type .form-kit__errors";
    assert.dom(error).hasText(i18n("category.validations.emoji_required"));
    await click(".category-style-trigger");
    await click("[data-d-tab='square']");
    assert
      .dom(error)
      .doesNotExist("the new style is valid before another save");
    assert.dom(".category-style-trigger").doesNotHaveAttribute("aria-invalid");
  });

  test("validates a closed emoji tab and resets the combined field", async function (assert) {
    await visit("/new-category");
    await fillIn("input.category-name", "Harbor");
    await click(".category-style-trigger");
    await click("[data-d-tab='emoji']");
    await click(".category-style-trigger");
    await click("#save-category");

    assert
      .dom("#control-style_type .form-kit__errors")
      .hasText(
        i18n("category.validations.emoji_required"),
        "a missing emoji is reported beside the field"
      );

    await click(".category-style-trigger");
    await click(".emoji-picker__section [data-emoji='smiley_cat']");
    assert
      .dom("#control-style_type .form-kit__errors")
      .doesNotExist(
        "selecting an emoji clears the submitted error immediately"
      );
    assert
      .dom(".category-style-trigger")
      .hasAria(
        "label",
        i18n("category.choose_style_with_emoji", { name: "smiley cat" })
      );
    assert
      .dom(".category-style-trigger img.emoji")
      .hasAttribute("title", "smiley_cat");
    await click(".category-style-trigger");
    assert
      .dom(".emoji-picker [data-emoji='smiley_cat'][aria-current='true']")
      .exists("marks the selected emoji");
    await click(".category-style-trigger");

    await click(".d-floating-control-bar .btn-default");
    assert
      .dom("input.category-name")
      .hasValue("", "restores the original name");
    assert
      .dom(".category-style-trigger .d-icon-square-full")
      .exists("restores the original icon");
    assert.dom("#control-style_type .form-kit__errors").doesNotExist();
  });
});
