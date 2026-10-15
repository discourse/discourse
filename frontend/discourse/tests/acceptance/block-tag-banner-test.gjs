import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { _renderBlocks } from "discourse/blocks/block-outlet";
import TagBanner from "discourse/blocks/builtin/tag-banner";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Blocks | tag-banner", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/tag/42/notifications.json", () =>
      helper.response({
        tag_notification: { id: 42, name: "test", notification_level: 1 },
      })
    );
    server.get("/tag/42/l/latest.json", () =>
      helper.response({
        users: [],
        primary_groups: [],
        topic_list: {
          can_create_topic: true,
          draft: null,
          draft_key: "new_topic",
          draft_sequence: 1,
          per_page: 30,
          tags: [{ id: 42, name: "test", topic_count: 1 }],
          topics: [],
        },
      })
    );
    server.get("/tag/test/info.json", () =>
      helper.response({
        tag_info: {
          id: 42,
          name: "test",
          slug: "test",
          description: "All about testing",
          topic_count: 1,
          staff: false,
          synonyms: [],
          tag_group_names: [],
          category_ids: [],
        },
        categories: [],
      })
    );
  });

  test("renders the tag name on a tag route and nothing off it", async function (assert) {
    // `tag-banner` is a built-in block (already registered at boot), so just
    // place it into a discovery-route outlet — re-registering would throw.
    _renderBlocks("sidebar-discovery", [{ block: TagBanner }]);

    await visit("/tag/test/42");
    assert
      .dom(".d-block-tag-banner")
      .exists("the banner renders on a tag route");
    assert
      .dom(".d-block-tag-banner__title")
      .includesText("test", "shows the tag name, not the numeric id");

    await visit("/latest");
    assert
      .dom(".d-block-tag-banner")
      .doesNotExist("the banner renders nothing off a tag route");
  });

  test("renders the tag description when showDescription is on", async function (assert) {
    _renderBlocks("sidebar-discovery", [
      { block: TagBanner, args: { showDescription: true } },
    ]);

    await visit("/tag/test/42");
    assert
      .dom(".d-block-tag-banner__description")
      .hasText("All about testing", "shows the fetched tag description");
  });

  test("hides the description when showDescription is off", async function (assert) {
    _renderBlocks("sidebar-discovery", [
      { block: TagBanner, args: { showDescription: false } },
    ]);

    await visit("/tag/test/42");
    assert
      .dom(".d-block-tag-banner")
      .exists("the banner still renders the tag name");
    assert
      .dom(".d-block-tag-banner__description")
      .doesNotExist("no description region when the toggle is off");
  });
});
