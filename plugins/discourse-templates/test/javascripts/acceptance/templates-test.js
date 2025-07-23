/* eslint-disable qunit/no-assert-equal */
/* eslint-disable qunit/no-loose-assertions */
import {
  click,
  currentURL,
  fillIn,
  triggerKeyEvent,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import { PLATFORM_KEY_MODIFIER } from "discourse/lib/keyboard-shortcuts";
import { cloneJSON } from "discourse/lib/object";
import {
  acceptance,
  count,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
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

  test("Filtering by tags", async (assert) => {
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
      "it should filter tags in the dropdown"
    );

    await tagDropdown.selectRowByIndex(0);
    assert.equal(
      count(".templates-list .template-item"),
      1,
      "it should filter replies by tag"
    );

    await click("#template-item-1 .templates-apply");

    assert.equal(
      query(".d-editor-input").value.trim(),
      "Cupcake ipsum dolor sit amet cotton candy cheesecake jelly. Candy canes sugar plum soufflé sweet roll jelly-o danish jelly muffin. I love jelly-o powder topping carrot cake toffee.",
      "it should insert the template in the composer"
    );
  });

  test("Filtering by text", async (assert) => {
    await visit("/");

    await click("#create-topic");
    await selectCategory();
    await click(".toolbar-menu__options-trigger");
    await click(`button[title="${i18n("templates.insert_template")}"]`);

    await fillIn(".templates-filter-bar input.templates-filter", "test");
    assert.equal(
      count(".templates-list .template-item"),
      2,
      "it should filter by text"
    );

    await click("#template-item-8 .templates-apply");

    assert.equal(
      query(".d-editor-input").value.trim(),
      "Testing testin **123**",
      "it should insert the template in the composer"
    );
  });

  test("Replacing variables", async (assert) => {
    await visit("/");

    await click("#create-topic");
    await selectCategory();
    await click(".toolbar-menu__options-trigger");
    await click(`button[title="${i18n("templates.insert_template")}"]`);

    await click("#template-item-9 .templates-apply");

    assert.equal(
      query(".d-editor-input").value.trim(),
      "Hi there, regards eviltrout.",
      "it should replace variables"
    );
  });

  test("Navigate to source", async (assert) => {
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
      "it should filter tags in the dropdown"
    );

    await tagDropdown.selectRowByIndex(0);
    assert.equal(
      count(".templates-list .template-item"),
      1,
      "it should filter replies by tag"
    );

    await click("#template-item-130 .template-item-title");
    await click("#template-item-130 .template-item-source-link");

    assert.equal(
      currentURL(),
      "/t/lorem-ipsum-dolor-sit-amet/130",
      "it should navigate to the source"
    );
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

    test("Filtering by tags", async (assert) => {
      await visit("/");

      await click("#create-topic");
      await selectCategory();
      await click(".toolbar-menu__options-trigger");
      await click(`button[title="${i18n("templates.insert_template")}"]`);

      assert.notOk(
        exists(".templates-filter-bar .tag-drop"),
        "tag drop down is not displayed"
      );
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

  const assertTemplateWasInserted = async (assert, textarea) => {
    const tagDropdown = selectKit(".templates-filter-bar .tag-drop");
    await tagDropdown.expand();

    await tagDropdown.fillInFilter(
      "cupcake",
      ".templates-filter-bar .tag-drop input"
    );
    await tagDropdown.selectRowByIndex(0);
    await click("#template-item-1 .templates-apply");

    assert.equal(
      textarea.value.trim(),
      "Cupcake ipsum dolor sit amet cotton candy cheesecake jelly. Candy canes sugar plum soufflé sweet roll jelly-o danish jelly muffin. I love jelly-o powder topping carrot cake toffee.",
      "it should insert the template in the textarea"
    );
  };

  test("Help | Added shortcut to help modal", async function (assert) {
    await visit("/");
    await triggerKeyEvent(document, "keypress", "?".charCodeAt(0));

    assert.ok(exists(".shortcut-category-templates"));
    assert.strictEqual(count(".shortcut-category-templates li"), 1);
  });

  test("Composer | Title field focused | Template is inserted", async (assert) => {
    await visit("/");

    await click("#create-topic");
    await selectCategory();
    const textarea = query(".d-editor-input");

    await triggerKeyboardShortcut();
    await assertTemplateWasInserted(assert, textarea);
  });

  test("Composer | Textarea focused | Template is inserted", async (assert) => {
    await visit("/");

    await click("#create-topic");
    await selectCategory();

    const textarea = query(".d-editor-input");
    await textarea.focus();

    await triggerKeyboardShortcut();
    await assertTemplateWasInserted(assert, textarea);
  });

  test("Modal | Templates modal | Show the modal if the preview is hidden", async (assert) => {
    await visit("/");

    await click("#create-topic");
    await selectCategory();

    await click(".toggle-preview");

    const textarea = query(".d-editor-input");
    await textarea.focus();

    await triggerKeyboardShortcut();
    assert.ok(
      exists(".d-modal.d-templates"),
      "It displayed the standard templates modal"
    );
  });

  test("Modal | Templates modal | Show the modal if a textarea is focused", async (assert) => {
    // if the text area is outside a modal then simply show the insert template modal
    // because there is no need to hijack
    await visit("/u/charlie/preferences/profile");

    const textarea = query(".d-editor-input");
    await textarea.focus();

    await triggerKeyboardShortcut();
    assert.ok(
      exists(".d-modal.d-templates"),
      "It displayed the standard templates modal"
    );
  });

  test("Modal | Templates modal | Template is inserted", async (assert) => {
    await visit("/u/charlie/preferences/profile");

    const textarea = query(".d-editor-input");
    await textarea.focus();

    await triggerKeyboardShortcut();
    await assertTemplateWasInserted(assert, textarea);
  });

  test("Modal | Templates modal | Template is inserted", async (assert) => {
    await visit("/u/charlie/preferences/profile");

    const textarea = query(".d-editor-input");
    await textarea.focus();

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
      "it should filter tags in the dropdown"
    );

    await tagDropdown.selectRowByIndex(0);
    assert.equal(
      count(".templates-list .template-item"),
      1,
      "it should filter replies by tag"
    );

    await click("#template-item-130 .template-item-title");
    await click("#template-item-130 .template-item-source-link");

    assert.equal(
      currentURL(),
      "/t/lorem-ipsum-dolor-sit-amet/130",
      "it should navigate to the source"
    );
  });

  test("Modal | Templates Modal | Stacked Modals | Template is inserted", async (assert) => {
    await visit("/t/topic-for-group-moderators/2480");
    await click(".show-more-actions");
    await click(".show-post-admin-menu");
    await click(".add-notice");

    const textarea = query(".d-modal__body textarea");
    await textarea.focus();

    await triggerKeyboardShortcut();
    await assertTemplateWasInserted(assert, textarea);
  });

  test("Modal | Templates Modal | Stacked Modals | Closing the template modal returns the focus to the original modal textarea", async (assert) => {
    await visit("/t/topic-for-group-moderators/2480");
    await click(".show-more-actions");
    await click(".show-post-admin-menu");
    await click(".add-notice");

    const textarea = query(".d-modal__body textarea");
    await textarea.focus();
    assert.notOk(
      exists(".d-templates-modal"),
      "the templates modal does not exist yet"
    );
    await triggerKeyboardShortcut();
    assert.ok(exists(".d-templates-modal"), "it displayed the templates modal");

    await click(".d-templates-modal .btn.modal-close");
    assert.strictEqual(
      textarea,
      document.activeElement,
      "it focused the original textarea again after closing the templates modal"
    );
  });
});

import topicFixtures from "discourse/tests/fixtures/topic";

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
