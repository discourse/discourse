import selectKit from "discourse/tests/helpers/select-kit-helper";
import { click, visit } from "@ember/test-helpers";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";

acceptance("Discourse Chat - Create channel modal", function (needs) {
  const maliciousText = '"<script></script>';

  needs.user({
    username: "tomtom",
    id: 1,
    can_chat: true,
    has_chat_enabled: true,
  });

  needs.settings({
    chat_enabled: true,
  });

  const catsCategory = {
    id: 1,
    name: "Cats",
    slug: "cats",
    permission: 1,
  };

  needs.site({
    categories: [
      catsCategory,
      {
        id: 2,
        name: maliciousText,
        slug: maliciousText,
        permission: 1,
      },
      {
        id: 3,
        name: "Kittens",
        slug: "kittens",
        permission: 1,
        parentCategory: catsCategory,
      },
    ],
  });

  needs.pretender((server, helper) => {
    server.get("/chat/:chatChannelId/messages.json", () =>
      helper.response({
        meta: { can_chat: true, user_silenced: false },
        chat_messages: [],
      })
    );

    server.get("/chat/chat_channels.json", () =>
      helper.response({
        public_channels: [],
        direct_message_channels: [],
      })
    );

    server.get("/chat/chat_channels/:chatChannelId", () =>
      helper.response({ id: 1, title: "something" })
    );

    server.get("/chat/api/chat_channels.json", () => helper.response([]));

    server.get(
      "/chat/api/category-chatables/:categoryId/permissions.json",
      (request) => {
        if (request.params.categoryId === "2") {
          return helper.response({
            allowed_groups: ["@<script>evilgroup</script>"],
            members_count: 2,
            private: true,
          });
        } else {
          return helper.response({
            allowed_groups: ["@awesomeGroup"],
            members_count: 2,
            private: true,
          });
        }
      }
    );
  });

  test("links to categories and selected category's security settings", async function (assert) {
    await visit("/chat/browse");
    await click(".new-channel-btn");

    assert.strictEqual(
      query(".create-channel-hint a").innerText,
      "category security settings"
    );
    assert.ok(query(".create-channel-hint a").href.includes("/categories"));

    let categories = selectKit(".create-channel-modal .category-chooser");
    await categories.expand();
    await categories.selectRowByName("Cats");

    assert.strictEqual(
      query(".create-channel-hint a").innerText,
      "security settings"
    );
    assert.ok(
      query(".create-channel-hint a").href.includes("/c/cats/edit/security")
    );
  });

  test("links to selected category's security settings works with nested subcategories", async function (assert) {
    await visit("/chat/browse");
    await click(".new-channel-btn");

    assert.strictEqual(
      query(".create-channel-hint a").innerText,
      "category security settings"
    );
    assert.ok(query(".create-channel-hint a").href.includes("/categories"));

    let categories = selectKit(".create-channel-modal .category-chooser");
    await categories.expand();
    await categories.selectRowByName("Kittens");

    assert.strictEqual(
      query(".create-channel-hint a").innerText,
      "security settings"
    );
    assert.ok(
      query(".create-channel-hint a").href.includes(
        "/c/cats/kittens/edit/security"
      )
    );
  });

  test("includes group names in the hint", async (assert) => {
    await visit("/chat/browse");
    await click(".new-channel-btn");

    assert.strictEqual(
      query(".create-channel-hint a").innerText,
      "category security settings"
    );
    assert.ok(query(".create-channel-hint a").href.includes("/categories"));

    let categories = selectKit(".create-channel-modal .category-chooser");
    await categories.expand();
    await categories.selectRowByName("Kittens");

    assert.strictEqual(
      query(".create-channel-hint").innerHTML.trim(),
      'Users in @awesomeGroup will have access to this channel per the <a href="/c/cats/kittens/edit/security" target="_blank">security settings</a>'
    );
  });

  test("escapes group name/category slug in the hint", async (assert) => {
    await visit("/chat/browse");
    await click(".new-channel-btn");

    assert.strictEqual(
      query(".create-channel-hint a").innerText,
      "category security settings"
    );
    assert.ok(query(".create-channel-hint a").href.includes("/categories"));

    const categories = selectKit(".create-channel-modal .category-chooser");
    await categories.expand();
    await categories.selectRowByValue(2);

    assert.strictEqual(
      query(".create-channel-hint").innerHTML.trim(),
      'Users in @&lt;script&gt;evilgroup&lt;/script&gt; will have access to this channel per the <a href="/c/&quot;<script></script>/edit/security" target="_blank">security settings</a>'
    );
    assert.ok(
      query(".create-channel-hint a").href.includes(
        "c/%22%3Cscript%3E%3C/script%3E/edit/security"
      )
    );
  });
});
