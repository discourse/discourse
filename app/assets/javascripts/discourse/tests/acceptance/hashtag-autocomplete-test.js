import {
  acceptance,
  emulateAutocomplete,
} from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("#hashtag autocompletion in composer", function (needs) {
  needs.user();
  needs.settings({
    tagging_enabled: true,
    enable_experimental_hashtag_autocomplete: true,
  });
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
            text: ":bug: Other Languages",
            slug: "other-languages",
            icon: "folder",
            relative_url: "/c/other-languages/28",
            ref: "other-languages",
            type: "category",
          },
          {
            text: "notes x 300",
            slug: "notes",
            icon: "tag",
            relative_url: "/tag/notes",
            ref: "notes",
            type: "tag",
          },
          {
            text: "photos x 281",
            slug: "photos",
            icon: "tag",
            relative_url: "/tag/photos",
            ref: "photos",
            type: "tag",
          },
        ],
      });
    });
  });

  test(":emoji: unescape in autocomplete search results", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await emulateAutocomplete(".d-editor-input", "abc #o");

    assert.dom(".hashtag-autocomplete__option").exists({ count: 3 });
    assert
      .dom(
        '.hashtag-autocomplete__option .hashtag-autocomplete__text img.emoji[title="bug"]'
      )
      .exists();
  });
});
