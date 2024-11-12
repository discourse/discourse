import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Chat | Hashtag CSS Generator", function (needs) {
  const category1 = { id: 1, color: "ff0000", name: "category1" };
  const category2 = { id: 2, color: "333", name: "category2" };
  const category3 = {
    id: 4,
    color: "2B81AF",
    parent_category_id: 1,
    name: "category3",
  };

  needs.settings({ chat_enabled: true });
  needs.user({
    has_chat_enabled: true,
  });
  needs.site({
    categories: [category1, category2, category3],
  });

  needs.pretender((server, helper) => {
    server.get("/chat/api/me/channels", () =>
      helper.response({
        public_channels: [
          {
            id: 44,
            chatable_id: 1,
            chatable_type: "Category",
            meta: { message_bus_last_ids: {} },
            current_user_membership: { following: true },
            chatable: category1,
          },
          {
            id: 74,
            chatable_id: 2,
            chatable_type: "Category",
            meta: { message_bus_last_ids: {} },
            current_user_membership: { following: true },
            chatable: category2,
          },
          {
            id: 88,
            chatable_id: 4,
            chatable_type: "Category",
            meta: { message_bus_last_ids: {} },
            current_user_membership: { following: true },
            chatable: category3,
          },
        ],
        direct_message_channels: [],
        meta: { message_bus_last_ids: {} },
        tracking: {
          channel_tracking: {
            44: { unread_count: 0, mention_count: 0 },
            74: { unread_count: 0, mention_count: 0 },
            88: { unread_count: 0, mention_count: 0 },
          },
          thread_tracking: {},
        },
      })
    );
  });

  test("hashtag CSS classes are generated", async function (assert) {
    await visit("/");
    assert
      .dom("style#hashtag-css-generator", document.head)
      .hasHtml(
        ".hashtag-category-badge { background-color: var(--primary-medium); }\n" +
          ".hashtag-color--category-1 { background-color: #ff0000; }\n" +
          ".hashtag-color--category-2 { background-color: #333; }\n" +
          ".hashtag-color--category-4 { background: linear-gradient(-90deg, #2B81AF 50%, #ff0000 50%); }"
      );
  });
});
