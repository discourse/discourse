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
          },
          {
            id: 300,
            text: "notes x 300",
            slug: "notes",
            icon: "tag",
            relative_url: "/tag/notes",
            ref: "notes",
            type: "tag",
          },
          {
            id: 281,
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
    await simulateKeys(".d-editor-input", "abc #o");

    assert.dom(".hashtag-autocomplete__option").exists({ count: 3 });
    assert
      .dom(
        '.hashtag-autocomplete__option .hashtag-autocomplete__text img.emoji[title="bug"]'
      )
      .exists();
  });
});
