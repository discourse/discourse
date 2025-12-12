import {
  click,
  currentURL,
  fillIn,
  focus,
  triggerKeyEvent,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import { PLATFORM_KEY_MODIFIER } from "discourse/services/keyboard-shortcuts";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";
import TemplatesFixtures from "../fixtures/templates-fixtures";

function templatesPretender(server, helper) {
  const repliesPath = "/discourse_templates";
  const replies = TemplatesFixtures[repliesPath];

  server.get(repliesPath, () => helper.response(replies));
  replies.templates.forEach((template) =>
    server.post(`${repliesPath}/${template.id}/use`, () => helper.response({}))
  );
}

async function selectCategory() {
  const categoryChooser = selectKit(".category-chooser");
  await categoryChooser.expand();
  await categoryChooser.selectRowByValue(2);
}

acceptance("discourse-templates", function (needs) {
  needs.settings({
    discourse_templates_enabled: true,
    allow_uncategorized_topics: true,
    tagging_enabled: true,
  });
  needs.user({
    can_use_templates: true,
  });

  needs.pretender(templatesPretender);

  test("Filtering by tags", async function (assert) {
    await visit("/");

    await click("#create-topic");
    await selectCategory();
    await click(".toolbar-menu__options-trigger");
    await click(`button[title="${i18n("templates.insert_template")}"]`);

    const tagDropdown = selectKit(".templates-filter-bar .tag-drop");
    await tagDropdown.expand();

    await tagDropdown.fillInFilter(
      "cupcake",
      ".templates-filter-bar .tag-drop input"
    );
    assert.deepEqual(
      tagDropdown.displayedContent(),
      [
        {
          name: "cupcakes",
          id: "cupcakes",
        },
      ],
      "filters tags in the dropdown"
    );

    await tagDropdown.selectRowByIndex(0);
    assert
      .dom(".templates-list .template-item")
      .exists({ count: 1 }, "filters replies by tag");

    await click("#template-item-1 .templates-apply");

    assert
      .dom(".d-editor-input")
      .includesValue(
        "Cupcake ipsum dolor sit amet cotton candy cheesecake jelly. Candy canes sugar plum soufflé sweet roll jelly-o danish jelly muffin. I love jelly-o powder topping carrot cake toffee.",
        "inserts the template in the composer"
      );
  });

  test("Filtering by text", async function (assert) {
    await visit("/");

    await click("#create-topic");
    await selectCategory();
    await click(".toolbar-menu__options-trigger");
    await click(`button[title="${i18n("templates.insert_template")}"]`);

    await fillIn(".templates-filter-bar input.templates-filter", "test");
    assert
      .dom(".templates-list .template-item")
      .exists({ count: 2 }, "filters by text");

    await click("#template-item-8 .templates-apply");

    assert
      .dom(".d-editor-input")
      .includesValue(
        "Testing testin **123**",
        "inserts the template in the composer"
      );
  });

  test("Replacing variables", async function (assert) {
    await visit("/");

    await click("#create-topic");
    await selectCategory();
    await click(".toolbar-menu__options-trigger");
    await click(`button[title="${i18n("templates.insert_template")}"]`);

    await click("#template-item-9 .templates-apply");

    assert
      .dom(".d-editor-input")
      .includesValue("Hi there, regards eviltrout.", "replaces variables");
  });

  test("Navigate to source", async function (assert) {
    await visit("/");

    await click("#create-topic");
    await selectCategory();
    await click(".toolbar-menu__options-trigger");
    await click(`button[title="${i18n("templates.insert_template")}"]`);

    const tagDropdown = selectKit(".templates-filter-bar .tag-drop");
    await tagDropdown.expand();

    await tagDropdown.fillInFilter(
      "lorem",
      ".templates-filter-bar .tag-drop input"
    );
    assert.deepEqual(
      tagDropdown.displayedContent(),
      [
        {
          name: "lorem",
          id: "lorem",
        },
      ],
      "filters tags in the dropdown"
    );

    await tagDropdown.selectRowByIndex(0);
    assert
      .dom(".templates-list .template-item")
      .exists({ count: 1 }, "filters replies by tag");

    await click("#template-item-130 .template-item-title");
    await click("#template-item-130 .template-item-source-link");

    assert.strictEqual(
      currentURL(),
      "/t/lorem-ipsum-dolor-sit-amet/130",
      "navigates to the source"
    );
  });

  test("Has ordering by relevance, usage, and title", async function (assert) {
    await visit("/");

    await click("#create-topic");
    await selectCategory();
    await click(".toolbar-menu__options-trigger");
    await click(`button[title="${i18n("templates.insert_template")}"]`);

    await fillIn(".templates-filter-bar input.templates-filter", "ipsum");
    const templateItems = document.querySelectorAll(
      ".templates-list .template-item-title-text"
    );
    const titles = Array.from(templateItems).map((el) => el.textContent.trim());

    assert.deepEqual(
      titles,
      [
        "Cupcake Ipsum excerpt",
        "Hipster ipsum excerpt",
        "Liquor ipsum excerpt",
        "Mussum Ipsum excerpt",
        "Lorem ipsum dolor sit amet",
      ],
      "orders templates by relevance, usage, and title"
    );
  });

  test("Remembers selected tag between openings", async function (assert) {
    await visit("/");

    await click("#create-topic");
    await selectCategory();
    await click(".toolbar-menu__options-trigger");
    await click(`button[title="${i18n("templates.insert_template")}"]`);

    const tagDropdown = selectKit(".templates-filter-bar .tag-drop");
    await tagDropdown.expand();

    await tagDropdown.fillInFilter(
      "cupcake",
      ".templates-filter-bar .tag-drop input"
    );
    await tagDropdown.selectRowByIndex(0);
    assert.dom(".templates-list .template-item").exists({ count: 1 });

    await click("#reply-control .toggle-save-and-close");

    await click("#create-topic");
    await selectCategory();
    await click(".toolbar-menu__options-trigger");
    await click(`button[title="${i18n("templates.insert_template")}"]`);
    assert
      .dom(".templates-list .template-item")
      .exists({ count: 1 }, "preserves selected tag across composer sessions");
  });
});

acceptance(
  "discourse-templates - with tags disabled in Settings",
  function (needs) {
    needs.settings({
      discourse_templates_enabled: true,
      tagging_enabled: false,
    });
    needs.user({
      can_use_templates: true,
    });

    needs.pretender(templatesPretender);

    test("Filtering by tags", async function (assert) {
      await visit("/");

      await click("#create-topic");
      await selectCategory();
      await click(".toolbar-menu__options-trigger");
      await click(`button[title="${i18n("templates.insert_template")}"]`);

      assert
        .dom(".templates-filter-bar .tag-drop")
        .doesNotExist("tag drop down is not displayed");
    });
  }
);

acceptance("discourse-templates | keyboard shortcut", function (needs) {
  needs.settings({
    discourse_templates_enabled: true,
    tagging_enabled: true,
  });
  needs.user({
    can_use_templates: true,
  });

  needs.pretender(templatesPretender);

  const triggerKeyboardShortcut = async () => {
    // Testing keyboard events is tough!
    const isMac = PLATFORM_KEY_MODIFIER.toLowerCase() === "meta";
    await triggerKeyEvent(document, "keydown", "I", {
      ...(isMac ? { metaKey: true } : { ctrlKey: true }),
      shiftKey: true,
    });
  };

  const assertTemplateWasInserted = async (assert, selector) => {
    const tagDropdown = selectKit(".templates-filter-bar .tag-drop");
    await tagDropdown.expand();

    await tagDropdown.fillInFilter(
      "cupcake",
      ".templates-filter-bar .tag-drop input"
    );
    await tagDropdown.selectRowByIndex(0);
    await click("#template-item-1 .templates-apply");

    assert
      .dom(selector)
      .includesValue(
        "Cupcake ipsum dolor sit amet cotton candy cheesecake jelly. Candy canes sugar plum soufflé sweet roll jelly-o danish jelly muffin. I love jelly-o powder topping carrot cake toffee.",
        "inserts the template in the textarea"
      );
  };

  test("Help | Added shortcut to help modal", async function (assert) {
    await visit("/");
    await triggerKeyEvent(document, "keypress", "?".charCodeAt(0));

    assert.dom(".shortcut-category-templates").exists();
    assert.dom(".shortcut-category-templates li").exists({ count: 1 });
  });

  test("Composer | Title field focused | Template is inserted", async function (assert) {
    await visit("/");

    await click("#create-topic");
    await selectCategory();

    await triggerKeyboardShortcut();
    await assertTemplateWasInserted(assert, ".d-editor-input");
  });

  test("Composer | Textarea focused | Template is inserted", async function (assert) {
    await visit("/");

    await click("#create-topic");
    await selectCategory();

    await focus(".d-editor-input");

    await triggerKeyboardShortcut();
    await assertTemplateWasInserted(assert, ".d-editor-input");
  });

  test("Modal | Templates modal | Show the modal if the preview is hidden", async function (assert) {
    await visit("/");

    await click("#create-topic");
    await selectCategory();

    await click(".toggle-preview");

    await focus(".d-editor-input");

    await triggerKeyboardShortcut();
    assert
      .dom(".d-modal.d-templates")
      .exists("displays the standard templates modal");
  });

  test("Modal | Templates modal | Show the modal if a textarea is focused", async function (assert) {
    // if the text area is outside a modal then simply show the insert template modal
    // because there is no need to hijack
    await visit("/u/charlie/preferences/profile");

    await focus(".d-editor-input");

    await triggerKeyboardShortcut();
    assert
      .dom(".d-modal.d-templates")
      .exists("displays the standard templates modal");
  });

  test("Modal | Templates modal | Template is inserted", async function (assert) {
    await visit("/u/charlie/preferences/profile");

    await focus(".d-editor-input");

    await triggerKeyboardShortcut();
    await assertTemplateWasInserted(assert, ".d-editor-input");
  });

  test("Modal | Templates modal | Template is inserted", async function (assert) {
    await visit("/u/charlie/preferences/profile");

    await focus(".d-editor-input");

    await triggerKeyboardShortcut();

    const tagDropdown = selectKit(".templates-filter-bar .tag-drop");
    await tagDropdown.expand();

    await tagDropdown.fillInFilter(
      "lorem",
      ".templates-filter-bar .tag-drop input"
    );
    assert.deepEqual(
      tagDropdown.displayedContent(),
      [
        {
          name: "lorem",
          id: "lorem",
        },
      ],
      "filters tags in the dropdown"
    );

    await tagDropdown.selectRowByIndex(0);
    assert
      .dom(".templates-list .template-item")
      .exists({ count: 1 }, "filters replies by tag");

    await click("#template-item-130 .template-item-title");
    await click("#template-item-130 .template-item-source-link");

    assert.strictEqual(
      currentURL(),
      "/t/lorem-ipsum-dolor-sit-amet/130",
      "navigates to the source"
    );
  });

  test("Modal | Templates Modal | Stacked Modals | Template is inserted", async function (assert) {
    await visit("/t/topic-for-group-moderators/2480");
    await click(".show-more-actions");
    await click(".show-post-admin-menu");
    await click(".add-notice");

    await focus(".d-modal__body textarea");

    await triggerKeyboardShortcut();
    await assertTemplateWasInserted(assert, ".d-modal__body textarea");
  });

  test("Modal | Templates Modal | Stacked Modals | Closing the template modal returns the focus to the original modal textarea", async function (assert) {
    await visit("/t/topic-for-group-moderators/2480");
    await click(".show-more-actions");
    await click(".show-post-admin-menu");
    await click(".add-notice");

    await focus(".d-modal__body textarea");
    assert
      .dom(".d-templates-modal")
      .doesNotExist("the templates modal does not exist yet");
    await triggerKeyboardShortcut();
    assert.dom(".d-templates-modal").exists("displays the templates modal");

    await click(".d-templates-modal .btn.modal-close");
    assert
      .dom(".d-modal__body textarea")
      .isFocused(
        "focuses the original textarea again after closing the templates modal"
      );
  });
});

acceptance("discourse-templates - buttons on topics", function (needs) {
  needs.user();
  needs.settings({
    allow_uncategorized_topics: true,
  });

  needs.pretender((server, helper) => {
    const topicResponse = cloneJSON(topicFixtures["/t/280/1.json"]);
    topicResponse.is_template = true;

    server.get("/t/280.json", () => helper.response(topicResponse));
    server.get("/raw/280/1", () => [200, {}, "post raw content"]);
  });

  test("Can open composer using button on topic", async function (assert) {
    await visit("/t/280");

    await click(".template-new-topic");
    assert.dom("textarea.d-editor-input").hasValue("post raw content");
  });
});
