import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Meta Tag Updater", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/about", () => helper.response({}));
  });

  test("updates OG title and URL", async function (assert) {
    await visit("/");
    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-trigger"
    );
    await click("a[href='/about']");

    assert
      .dom("meta[property='og:title']", document)
      .hasAttribute("content", document.title, "updates OG title");
    assert
      .dom("meta[property='og:url']", document)
      .hasAttribute("content", /\/about$/, "updates OG URL");
    assert
      .dom("meta[name='twitter:title']", document)
      .hasAttribute("content", document.title, "updates Twitter title");
    assert
      .dom("meta[name='twitter:url']", document)
      .hasAttribute("content", /\/about$/, "updates Twitter URL");
    assert
      .dom("link[rel='canonical']", document)
      .hasAttribute("href", /\/about$/, "updates the canonical URL");
  });
});

acceptance("Meta Tag Updater - Embedded Topics", function (needs) {
  const embedUrl = "https://example.com/original-article";

  needs.pretender((server, helper) => {
    server.get("/t/280.json", () =>
      helper.response({
        post_stream: {
          posts: [
            {
              id: 398,
              name: null,
              username: "tms",
              avatar_template:
                "/letter_avatar_proxy/v4/letter/t/a9a28c/{size}.png",
              created_at: "2019-07-03T02:47:42.619Z",
              raw: "This is a test topic",
              cooked: "<p>This is a test topic</p>",
              post_number: 1,
              post_type: 1,
              updated_at: "2019-07-03T02:47:42.619Z",
              reply_count: 0,
              quote_count: 0,
              incoming_link_count: 0,
              reads: 1,
              readers_count: 0,
              score: 0,
              yours: true,
              topic_id: 280,
              topic_slug: "internationalization-localization",
              user_id: 1,
              primary_group_name: null,
              trust_level: 1,
              can_edit: true,
              can_delete: false,
              can_recover: false,
              can_wiki: true,
            },
          ],
          stream: [398],
        },
        id: 280,
        title: "Internationalization / localization",
        fancy_title: "Internationalization / localization",
        posts_count: 1,
        created_at: "2019-07-03T02:47:42.215Z",
        views: 1,
        reply_count: 0,
        like_count: 0,
        visible: true,
        closed: false,
        archived: false,
        archetype: "regular",
        slug: "internationalization-localization",
        category_id: 1,
        word_count: 4,
        user_id: 1,
        canonical_url: embedUrl,
        chunk_size: 20,
        details: {
          can_create_post: true,
          participants: [
            {
              id: 1,
              username: "tms",
              avatar_template:
                "/letter_avatar_proxy/v4/letter/t/a9a28c/{size}.png",
              post_count: 1,
              primary_group_name: null,
            },
          ],
          created_by: {
            id: 1,
            username: "tms",
            avatar_template:
              "/letter_avatar_proxy/v4/letter/t/a9a28c/{size}.png",
          },
          last_poster: {
            id: 1,
            username: "tms",
            avatar_template:
              "/letter_avatar_proxy/v4/letter/t/a9a28c/{size}.png",
          },
        },
      })
    );
  });

  test("uses canonical_url from topic when present", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert
      .dom("link[rel='canonical']", document)
      .hasAttribute(
        "href",
        embedUrl,
        "uses the embed URL as canonical for embedded topics"
      );
  });
});
