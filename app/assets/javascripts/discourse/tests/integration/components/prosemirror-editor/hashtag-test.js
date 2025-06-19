import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - hashtag extension",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      pretender.get("/hashtags", () =>
        response({
          dev: [
            {
              type: "tag",
              slug: "dev",
              icon: "tag",
              id: 1,
            },
          ],
          product: [
            {
              type: "category",
              style_type: "square",
              slug: "product",
              id: 2,
            },
          ],
          coffee: [
            {
              type: "category",
              emoji: "coffee",
              style_type: "emoji",
              slug: "coffee",
              id: 3,
            },
          ],
          discuss: [
            {
              type: "category",
              icon: "comment",
              style_type: "icon",
              slug: "discuss",
              id: 4,
            },
          ],
        })
      );
    });

    const testCases = {
      hashtag: [
        "#product",
        '<p><a class="hashtag-cooked" data-name="product" data-processed="true" data-valid="true" contenteditable="false" draggable="true"><span class=\"hashtag-category-square hashtag-color--category-2\"></span>product</a></p>',
        "#product",
      ],
      "text with hashtag": [
        "Hello #product",
        '<p>Hello <a class="hashtag-cooked" data-name="product" data-processed="true" data-valid="true" contenteditable="false" draggable="true"><span class=\"hashtag-category-square hashtag-color--category-2\"></span>product</a></p>',
        "Hello #product",
      ],
      "hashtag after heading": [
        "## Hello\n\n#product",
        '<h2>Hello</h2><p><a class="hashtag-cooked" data-name="product" data-processed="true" data-valid="true" contenteditable="false" draggable="true"><span class=\"hashtag-category-square hashtag-color--category-2\"></span>product</a></p>',
        "## Hello\n\n#product",
      ],
      "invalid hashtag": [
        "Hello #invalid, how are you?",
        '<p>Hello <a class="hashtag-cooked" data-name="invalid" data-processed="true" data-valid="false" contenteditable="false" draggable="true">#invalid</a>, how are you?</p>',
        "Hello #invalid, how are you?",
      ],
      "with regular tags": [
        "Hello #dev",
        '<p>Hello <a class="hashtag-cooked" data-name="dev" data-processed="true" data-valid="true" contenteditable="false" draggable="true"><svg class=\"fa d-icon d-icon-tag svg-icon hashtag-color--tag-1 svg-string\" aria-hidden=\"true\" xmlns=\"http://www.w3.org/2000/svg\"><use href=\"#tag\"></use></svg>dev</a></p>',
        "Hello #dev",
      ],
      "hashtag with emoji": [
        "Time for #coffee",
        '<p>Time for <a class="hashtag-cooked" data-name="coffee" data-processed="true" data-valid="true" contenteditable="false" draggable="true"><span class=\"hashtag-category-emoji hashtag-color--category-3\"><img width=\"20\" height=\"20\" src=\"/images/emoji/twitter/coffee.png?v=14\" title=\"coffee\" alt=\"coffee\" class=\"emoji\"></span>coffee</a></p>',
        "Time for #coffee",
      ],
      "hashtag with icon": [
        "Lets #discuss",
        '<p>Lets <a class="hashtag-cooked" data-name="discuss" data-processed="true" data-valid="true" contenteditable="false" draggable="true"><span class=\"hashtag-category-icon hashtag-color--category-4\"><svg class=\"fa d-icon d-icon-comment svg-icon svg-string\" aria-hidden=\"true\" xmlns=\"http://www.w3.org/2000/svg\"><use href=\"#comment\"></use></svg></span>discuss</a></p>',
        "Lets #discuss",
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
