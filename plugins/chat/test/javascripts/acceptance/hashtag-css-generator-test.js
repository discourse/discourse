import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Chat | Hashtag CSS Generator", function (needs) {
  const category1 = { id: 1, color: "ff0000" };
  const category2 = { id: 2, color: "333" };
  const category3 = { id: 4, color: "2B81AF", parentCategory: { id: 1 } };

  needs.settings({ chat_enabled: true });
  needs.user({
    has_chat_enabled: true,
    chat_channels: {
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
    },
  });
  needs.site({
    categories: [category1, category2, category3],
  });

  test("hashtag CSS classes are generated", async function (assert) {
    await visit("/");
    const cssTag = document.querySelector("style#hashtag-css-generator");
    assert.equal(
      cssTag.innerHTML,

      ".hashtag-color--category-1 {\n  background: linear-gradient(90deg, var(--category-1-color) 50%, var(--category-1-color) 50%);\n}\n.hashtag-color--category-2 {\n  background: linear-gradient(90deg, var(--category-2-color) 50%, var(--category-2-color) 50%);\n}\n.hashtag-color--category-4 {\n  background: linear-gradient(90deg, var(--category-4-color) 50%, var(--category-1-color) 50%);\n}\n.hashtag-color--channel-44 { color: var(--category-1-color); }\n.hashtag-color--channel-74 { color: var(--category-2-color); }\n.hashtag-color--channel-88 { color: var(--category-4-color); }"
    );
  });
});
