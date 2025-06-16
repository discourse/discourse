import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - mention extension",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      pretender.get("/composer/mentions", () =>
        response({
          users: ["eviltrout", "john"],
          user_reasons: {},
          groups: {
            support: { user_count: 1 },
            unmentionable: { user_count: 5 },
          },
          group_reasons: { unmentionable: "not_mentionable" },
          max_users_notified_per_group_mention: 100,
        })
      );
    });

    const testCases = {
      mention: [
        "@eviltrout",
        '<p><a class="mention" data-name="eviltrout" data-valid="true" contenteditable="false" draggable="true">@eviltrout</a></p>',
        "@eviltrout",
      ],
      "text with mention": [
        "Hello @eviltrout",
        '<p>Hello <a class="mention" data-name="eviltrout" data-valid="true" contenteditable="false" draggable="true">@eviltrout</a></p>',
        "Hello @eviltrout",
      ],
      "mention after heading": [
        "## Hello\n\n@eviltrout",
        '<h2>Hello</h2><p><a class="mention" data-name="eviltrout" data-valid="true" contenteditable="false" draggable="true">@eviltrout</a></p>',
        "## Hello\n\n@eviltrout",
      ],
      "group mention": [
        "Maybe @support can help",
        '<p>Maybe <a class="mention" data-name="support" data-valid="true" contenteditable="false" draggable="true">@support</a> can help</p>',
        "Maybe @support can help",
      ],
      "group and user mention": [
        "Hey @john, I think @support can help here",
        '<p>Hey <a class="mention" data-name="john" data-valid="true" contenteditable="false" draggable="true">@john</a>, I think <a class="mention" data-name="support" data-valid="true" contenteditable="false" draggable="true">@support</a> can help here</p>',
        "Hey @john, I think @support can help here",
      ],
      "invalid mention": [
        "Hello @invalid, how are you?",
        '<p>Hello <a class="mention" data-name="invalid" data-valid="false" contenteditable="false" draggable="true">@invalid</a>, how are you?</p>',
        "Hello @invalid, how are you?",
      ],
    };

    Object.entries(testCases).forEach(
      ([name, [markdown, expectedHtml, expectedMarkdown]]) => {
        test(name, async function (assert) {
          this.siteSettings.rich_editor = true;

          await testMarkdown(assert, markdown, expectedHtml, expectedMarkdown);
        });
      }
    );
  }
);
