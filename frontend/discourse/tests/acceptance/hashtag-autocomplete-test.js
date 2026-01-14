import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  simulateKeys,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("#hashtag autocompletion in composer", function (needs) {
  needs.user();
  needs.settings({ tagging_enabled: true });
  needs.pretender((server, helper) => {
    server.get("/hashtags", () => {
      return helper.response({
        category: [],
        tag: [],
      });
    });
    server.get("/hashtags/search.json", () => {
      return helper.response({
        results: [
          {
            id: 28,
            text: ":bug: Other Languages",
            slug: "other-languages",
            colors: ["FF0000"],
            icon: "folder",
            relative_url: "/c/other-languages/28",
            ref: "other-languages",
            type: "category",
            style_type: "square",
          },
          {
            id: 99,
            text: "Fun stuff",
            slug: "fun-stuff",
            colors: ["55FF00"],
            icon: "bell",
            relative_url: "/c/fun-stuff/99",
            ref: "fun-stuff",
            type: "category",
            style_type: "icon",
          },
          {
            id: 123,
            text: "organization",
            slug: "organization",
            colors: ["0000FF", "00FFFF"],
            emoji: "joy",
            icon: "folder",
            relative_url: "/c/organization/123",
            ref: "organization",
            type: "category",
            style_type: "emoji",
          },
          {
            id: 300,
            text: "notes x 300",
            slug: "notes",
            icon: "tag",
            relative_url: "/tag/notes",
            ref: "notes",
            type: "tag",
            style_type: "icon",
          },
          {
            id: 281,
            text: "photos x 281",
            slug: "photos",
            icon: "tag",
            relative_url: "/tag/photos",
            ref: "photos",
            type: "tag",
            style_type: "icon",
          },
        ],
      });
    });
  });

  test(":emoji: unescape in autocomplete search results", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await simulateKeys(".d-editor-input", "abc #o");

    assert.dom(".hashtag-autocomplete__option").exists({ count: 5 });
    assert
      .dom(
        '.hashtag-autocomplete__option .hashtag-autocomplete__text img.emoji[title="bug"]'
      )
      .exists();
  });

  test("iconHTML is correctly generated for various hashtag types and style_type configs", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await simulateKeys(".d-editor-input", "abc #o");

    assert.dom(".hashtag-autocomplete__option").exists({ count: 5 });
    assert
      .dom(
        ".hashtag-autocomplete__option .d-icon.d-icon-tag.hashtag-color--tag-300"
      )
      .exists();
    assert
      .dom(
        ".hashtag-autocomplete__option .hashtag-category-square.hashtag-color--category-28"
      )
      .exists();
    assert
      .dom(
        ".hashtag-autocomplete__option .hashtag-category-icon.hashtag-color--category-99 svg.svg-icon.d-icon-bell"
      )
      .exists();
    assert
      .dom(
        ".hashtag-autocomplete__option .hashtag-category-emoji.hashtag-color--category-123 img.emoji[title='joy']"
      )
      .exists();
  });
});
