import {
  click,
  fillIn,
  findAll,
  settled,
  triggerKeyEvent,
  visit,
  waitFor,
} from "@ember/test-helpers";
import { test } from "qunit";
import { resetRichEditorExtensions } from "discourse/lib/composer/rich-editor-extensions";
import { AUTO_GROUPS } from "discourse/lib/constants";
import {
  acceptance,
  metaModifier,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";
import { displayPollBuilderButton } from "discourse/plugins/poll/helpers/display-poll-builder-button";

acceptance("Poll Builder - polls are enabled", function (needs) {
  needs.user();
  needs.hooks.beforeEach(() => resetRichEditorExtensions());
  needs.hooks.afterEach(() => resetRichEditorExtensions());
  needs.settings({
    default_composer_category: 1,
    poll_enabled: true,
    poll_create_allowed_groups: AUTO_GROUPS.trust_level_1,
  });

  test("edits an existing rich editor poll in place", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn(
      ".d-editor-input",
      "Before\n\n[poll]\n* First\n* Second\n[/poll]\n\nBetween\n\n[poll name=second type=multiple min=1 max=2 public=false chartType=pie results=on_vote dynamic=true status=closed order=asc]\n# **Question**\n* **Yes**\n* [No](https://example.com)\n[/poll]\n\nAfter"
    );
    await click(".composer-toggle-switch");
    await waitFor(".ProseMirror");
    await settled();
    await click(findAll(".composer-poll-node__edit")[1]);

    assert
      .dom(".poll-ui-builder .d-modal__title")
      .hasText("Edit poll", "opens the editing builder");
    assert
      .dom(".poll-option-value input")
      .exists({ count: 2 }, "opens the existing poll in simple mode");
    await click(".advanced-mode-btn");
    assert
      .dom(".poll-type-value-multiple")
      .hasClass("active", "restores the poll type");
    assert
      .dom(".poll-title textarea")
      .hasValue("**Question**", "preserves title formatting");
    assert
      .dom(".poll-options textarea")
      .hasValue(
        "**Yes**\n[No](https://example.com)",
        "preserves option formatting"
      );

    await fillIn(".poll-title textarea", "Updated question");
    await fillIn(
      ".poll-options textarea",
      "**Yes**\n[No](https://example.com)\nMaybe"
    );
    await click(".insert-poll");

    assert
      .dom(".ProseMirror .poll")
      .exists({ count: 2 }, "replaces rather than appends a poll");
    assert
      .dom('.ProseMirror .poll[data-poll-name="second"] h1')
      .hasText("Updated question", "updates the selected poll");
    assert
      .dom(
        '.ProseMirror .poll[data-poll-name="second"] .composer-poll-node__content li'
      )
      .exists({ count: 3 }, "updates its options");
    assert
      .dom('.ProseMirror .poll[data-poll-name="second"]')
      .hasAttribute(
        "data-poll-status",
        "closed",
        "does not reopen a closed poll"
      );
    assert
      .dom('.ProseMirror .poll[data-poll-name="second"]')
      .hasAttribute("data-poll-charttype", "pie", "preserves chart type");
    assert
      .dom('.ProseMirror .poll[data-poll-name="second"]')
      .hasAttribute(
        "data-poll-results",
        "on_vote",
        "preserves results visibility"
      );
    assert
      .dom('.ProseMirror .poll[data-poll-name="second"]')
      .hasAttribute("data-poll-public", "false", "preserves voter privacy");
    assert
      .dom('.ProseMirror .poll[data-poll-name="second"]')
      .hasAttribute("data-poll-dynamic", "true", "preserves dynamic voting");

    await triggerKeyEvent(".ProseMirror", "keydown", "Z", metaModifier);
    assert
      .dom('.ProseMirror .poll[data-poll-name="second"] h1')
      .hasText("Question", "undo restores the original poll");
    await triggerKeyEvent(".ProseMirror", "keydown", "Z", {
      ...metaModifier,
      shiftKey: true,
    });
    assert
      .dom('.ProseMirror .poll[data-poll-name="second"] h1')
      .hasText("Updated question", "redo reapplies the edit");

    await click(".composer-toggle-switch");
    assert
      .dom(".d-editor-input")
      .hasValue(
        "Before\n\n[poll]\n* First\n* Second\n\n[/poll]\n\nBetween\n\n[poll type=multiple results=on_vote public=false name=second chartType=pie max=2 min=1 dynamic=true status=closed order=asc]\n# Updated question\n\n* **Yes**\n* [No](https://example.com)\n* Maybe\n\n[/poll]\n\nAfter",
        "preserves the other poll and surrounding text"
      );
  });

  test("cancelling poll edits leaves the document unchanged", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn(".d-editor-input", "[poll]\n* First\n* Second\n[/poll]");
    await click(".composer-toggle-switch");
    await waitFor(".ProseMirror");
    await settled();
    await click(".composer-poll-node__edit");
    await fillIn(".poll-option-value:first-of-type input", "Changed");
    await click(".poll-ui-builder .d-modal__footer .btn-flat");

    assert
      .dom(".ProseMirror .composer-poll-node__content li:first-child")
      .hasText("First", "cancel does not apply changed options");
    await click(".composer-poll-node__edit");
    assert
      .dom(".poll-option-value:first-of-type input")
      .hasValue("First", "reopening loads the unchanged poll");
    assert
      .dom(".poll-option-value:nth-of-type(2) input")
      .hasValue("Second", "preserves its remaining options");
    await click(".insert-poll");
    assert
      .dom(".ProseMirror .poll")
      .doesNotHaveAttribute(
        "data-poll-name",
        "saving preserves the unnamed poll's identity"
      );
  });

  test("editing preserves structured poll content", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn(
      ".d-editor-input",
      "[poll close=2050-01-01]\n## Question\n* First paragraph\n\n  Second paragraph\n* Simple\n[/poll]"
    );
    await click(".composer-toggle-switch");
    await waitFor(".ProseMirror");
    await settled();

    assert
      .dom(".ProseMirror .poll h1")
      .hasText("Question", "renders the poll title");
    assert
      .dom(".composer-poll-node__content li:first-child p")
      .exists({ count: 2 }, "loads both paragraphs in the first option");

    await click(".composer-poll-node__edit");
    await click(".insert-poll");

    assert
      .dom(".ProseMirror .poll h1")
      .hasText("Question", "preserves the poll title");
    assert
      .dom(".composer-poll-node__content li:first-child p")
      .exists({ count: 2 }, "keeps both paragraphs attached to the option");
    assert
      .dom(".ProseMirror .poll")
      .hasAttribute(
        "data-poll-close",
        "2050-01-01",
        "preserves the original date-only close value"
      );
  });

  test("a newly inserted rich editor poll can be edited", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await click(".composer-toggle-switch");
    await waitFor(".ProseMirror");
    await click(".toolbar-menu__options-trigger");
    await click(`button[title='${i18n("poll.ui_builder.title")}']`);
    await fillIn(".poll-option-value input", "First");
    await click(".poll-option-add");
    await fillIn(".poll-option-value:nth-of-type(2) input", "Second");
    await click(".insert-poll");
    await click(".composer-poll-node__edit");

    assert
      .dom(".poll-option-value:first-of-type input")
      .hasValue("First", "loads the newly inserted poll in simple mode");
    assert
      .dom(".poll-option-value:nth-of-type(2) input")
      .hasValue("Second", "loads its remaining options");
    await fillIn(".poll-option-value:first-of-type input", "Updated");
    await click(".insert-poll");
    assert
      .dom(".ProseMirror .poll")
      .exists({ count: 1 }, "keeps a single poll");
    assert
      .dom(".ProseMirror .composer-poll-node__content li:first-child")
      .hasText("Updated", "saves the edited option");
  });

  test("edits a numeric poll's range and step", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn(
      ".d-editor-input",
      "[poll type=number min=0 max=10 step=2]\n[/poll]"
    );
    await click(".composer-toggle-switch");
    await waitFor(".ProseMirror");
    await settled();
    await click(".composer-poll-node__edit");

    assert.dom(".poll-options-min").hasValue("0", "restores the lower bound");
    assert.dom(".poll-options-max").hasValue("10", "restores the upper bound");
    assert.dom(".poll-options-step").hasValue("2", "restores the step");
    await fillIn(".poll-options-max", "8");
    await fillIn(".poll-options-step", "4");
    await click(".insert-poll");

    assert
      .dom(".ProseMirror .composer-poll-node__content li")
      .exists({ count: 3 }, "regenerates the numeric options");
    assert
      .dom(".ProseMirror .composer-poll-node__content li:last-child")
      .hasText("8", "keeps the edited maximum");
    await click(".composer-toggle-switch");
    assert
      .dom(".d-editor-input")
      .hasValue(
        "[poll type=number results=always public=false max=8 min=0 step=4]\n[/poll]\n\n",
        "serializes the numeric range without list items"
      );
  });

  test("regular user - sufficient trust level", async function (assert) {
    updateCurrentUser({
      moderator: false,
      admin: false,
      trust_level: 1,
      can_create_poll: true,
    });

    await displayPollBuilderButton();

    const pollBuilderButtonSelector = `button[title='${i18n(
      "poll.ui_builder.title"
    )}']`;

    assert.dom(pollBuilderButtonSelector).exists("it shows the builder button");

    await click(pollBuilderButtonSelector);

    assert
      .dom(".poll-type-value-regular.active")
      .exists("regular type is active");

    await click(".poll-type-value-multiple");

    assert
      .dom(".poll-type-value-multiple.active")
      .exists("multiple type is active");

    await click(".poll-type-value-regular");

    assert
      .dom(".poll-type-value-regular.active")
      .exists("regular type is active");
  });

  test("regular user - insufficient trust level", async function (assert) {
    updateCurrentUser({
      moderator: false,
      admin: false,
      trust_level: 0,
      can_create_poll: false,
    });

    await displayPollBuilderButton();

    assert
      .dom(`button[title='${i18n("poll.ui_builder.title")}']`)
      .doesNotExist("hides the builder button");
  });

  test("staff - with insufficient trust level", async function (assert) {
    updateCurrentUser({ moderator: true, trust_level: 0 });

    await displayPollBuilderButton();

    assert
      .dom(`button[title='${i18n("poll.ui_builder.title")}']`)
      .exists("it shows the builder button");
  });
});
