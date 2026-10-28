import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Blog editor", function (needs) {
  needs.user({ admin: true, moderator: false });
  needs.settings({
    blog_enabled: true,
    blog_category: 1,
    blog_drafts_category: 2,
    blog_url: "https://blog.example.com",
  });

  let draft;
  let published;

  needs.hooks.beforeEach(() => {
    draft = {
      id: 123,
      can_publish: true,
      source_topic_id: 123,
      source_url: "/t/an-unfinished-story/123",
      title: "An unfinished story",
      path: "/an-unfinished-story",
      url: "https://blog.example.com/an-unfinished-story",
      excerpt: "",
      featured: false,
      draft: true,
      published: false,
      live: false,
      replies: 0,
      topic_url: "/t/an-unfinished-story/123",
      preview_url: "/blog-editor/preview/123",
    };
    published = {
      ...draft,
      id: 124,
      title: "A published story",
      draft: false,
      published: true,
      live: true,
      published_at: "2026-09-01T14:20:00.000Z",
      replies: 2,
    };
    pretender.get("/blog-editor.json", (request) => {
      const status = request.queryParams.filter;
      return response({
        topics: {
          all: [draft, published],
          drafts: [draft],
          published: [published],
          unpublished: [],
        }[status || "all"],
        blog_url: "https://blog.example.com",
      });
    });
  });

  test("filters private drafts and published articles", async function (assert) {
    await visit("/blog-editor");
    assert
      .dom(".blog-dashboard__row")
      .exists({ count: 2 }, "both editorial states are listed");
    await click(".blog-dashboard__filters button:nth-child(2)");
    assert.dom('[data-topic-id="123"]').exists("private drafts are shown");
    assert
      .dom('[data-topic-id="124"]')
      .doesNotExist("published articles are filtered out");
    await click(".blog-dashboard__filters button:nth-child(3)");
    assert.dom('[data-topic-id="124"]').exists("published articles are shown");
    assert
      .dom('[data-topic-id="123"]')
      .doesNotExist("private drafts are filtered out");
    await click(".blog-dashboard__filters button:nth-child(4)");
    assert
      .dom(".blog-dashboard__row")
      .doesNotExist("unpublished filtering can return an empty result");
  });

  test("separates published articles from private correction work", async function (assert) {
    published = {
      ...published,
      title: "Private correction title",
      public_title: "The live article title",
      public_excerpt: "The published introduction",
      public_path: "/live-article",
      url: "https://blog.example.com/live-article",
      discussion_url: "/t/live-article/200",
      source_url: "/t/private-correction/201",
      draft_correction: true,
    };
    await visit("/blog-editor");
    assert
      .dom('[data-topic-id="124"] .d-table__overview-link')
      .hasText(
        "The live article title",
        "published entries use the live title rather than the working copy"
      );
    assert
      .dom('[data-topic-id="124"] .d-table__overview-link')
      .hasAttribute(
        "href",
        "/t/live-article/200",
        "the main link opens the public discussion"
      );
    assert
      .dom('[data-topic-id="124"] .blog-dashboard__edit-private')
      .hasAttribute(
        "href",
        published.source_url,
        "the working copy is where publishing happens"
      );
    assert
      .dom('[data-topic-id="124"] .blog-dashboard__edit-private')
      .hasText("Edit", "live articles are edited through their working copy");
    assert
      .dom('[data-topic-id="123"] .blog-dashboard__edit-private')
      .hasText("Edit", "drafts use the same edit action");
    await click('[data-topic-id="124"] .blog-dashboard__more-actions');
    assert
      .dom(".blog-dashboard__discussion")
      .doesNotExist("the title already opens the public discussion");
    assert
      .dom(".blog-dashboard__view-live")
      .hasAttribute("href", published.url, "live articles link to the blog");
    assert
      .dom(".blog-dashboard__preview")
      .hasText(
        "Preview changes",
        "live articles with a correction preview the working copy"
      );
    await click('[data-topic-id="124"] .blog-dashboard__more-actions');
    assert
      .dom('[data-topic-id="124"] .blog-dashboard__status')
      .hasText(
        "Published",
        "corrections do not mark a live article unpublished"
      );
    assert
      .dom('[data-topic-id="124"] .blog-dashboard__correction')
      .hasText("Draft correction", "pending editorial changes are identified");
    assert
      .dom('[data-topic-id="123"] .blog-dashboard__status')
      .hasText("Draft", "never-published articles are drafts");
    assert
      .dom('[data-topic-id="124"] .blog-dashboard__status')
      .hasClass("--success", "live articles use the success status style");
    assert
      .dom('[data-topic-id="123"] .blog-dashboard__status')
      .doesNotHaveClass("--success", "drafts use the neutral status style");
    assert
      .dom('[data-topic-id="123"] .blog-dashboard__correction')
      .doesNotExist("new drafts are not corrections");
  });

  test("lists status, publication date, replies, and row actions", async function (assert) {
    published = {
      ...published,
      discussion_url: "/t/live-article/200",
      scheduled_at: "2026-10-01T10:00:00.000Z",
    };
    await visit("/blog-editor");
    assert
      .dom('[data-topic-id="124"] .blog-dashboard__scheduled')
      .hasText("Scheduled", "scheduled releases are identified");
    assert
      .dom('[data-topic-id="124"] .blog-dashboard__published .relative-date')
      .exists("published articles show when they went live");
    assert
      .dom('[data-topic-id="123"] .blog-dashboard__published .relative-date')
      .doesNotExist("drafts have no publication date");
    assert
      .dom('[data-topic-id="124"] .blog-dashboard__replies')
      .includesText("2", "published articles show their reply count");
    assert
      .dom('[data-topic-id="123"] .blog-dashboard__published')
      .includesText("—", "drafts show a placeholder for the publication date");
    assert
      .dom('[data-topic-id="123"] .blog-dashboard__replies')
      .includesText("—", "drafts without a discussion show a placeholder");

    await click('[data-topic-id="123"] .blog-dashboard__more-actions');
    assert
      .dom(".blog-dashboard__preview")
      .hasAttribute("href", draft.preview_url, "drafts can be previewed");
    assert
      .dom(".blog-dashboard__view-live")
      .doesNotExist("drafts have no live article to open");

    await click('[data-topic-id="123"] .blog-dashboard__more-actions');
    await click('[data-topic-id="124"] .blog-dashboard__more-actions');
    assert
      .dom(".blog-dashboard__preview")
      .doesNotExist("live articles without changes have nothing to preview");
    assert
      .dom(".blog-dashboard__view-live")
      .exists("live articles can be opened on the blog");
  });

  test("keeps the discussion reachable for unpublished articles", async function (assert) {
    draft = {
      ...draft,
      draft: false,
      published: false,
      discussion_url: "/t/withdrawn-story/300",
    };
    await visit("/blog-editor");
    await click('[data-topic-id="123"] .blog-dashboard__more-actions');
    assert
      .dom(".blog-dashboard__discussion")
      .hasAttribute(
        "href",
        "/t/withdrawn-story/300",
        "withdrawn articles still link to their public discussion"
      );
  });

  test("creates a private working copy for articles without one", async function (assert) {
    published = { ...published, source_url: null, source_topic_id: null };
    pretender.post("/blog-editor/publications/124/prepare.json", () => {
      assert.step("prepare");
      return response({
        ...published,
        source_url: "/t/internationalization-localization/280",
      });
    });
    await visit("/blog-editor");
    assert
      .dom('[data-topic-id="124"] .blog-dashboard__edit-private')
      .hasText("Edit", "creating a working copy uses the same edit action");
    await click('[data-topic-id="124"] .blog-dashboard__edit-private');
    assert.verifySteps(["prepare"], "a working copy is created on demand");
    assert.strictEqual(
      currentURL(),
      "/t/internationalization-localization/280",
      "the editor lands on the new working copy"
    );
  });

  test("marks exactly one article filter as selected", async function (assert) {
    await visit("/blog-editor");
    const filters = ".blog-dashboard__filters";
    assert
      .dom(`${filters} button[aria-pressed="true"]`)
      .hasText("All articles", "all articles is selected initially");

    for (const [index, label] of [
      "Drafts",
      "Published",
      "Not on the blog",
      "All articles",
    ].entries()) {
      const position = index === 3 ? 1 : index + 2;
      await click(`${filters} button:nth-child(${position})`);
      assert
        .dom(`${filters} button[aria-pressed="true"]`)
        .exists({ count: 1 }, "exactly one filter is selected");
      assert
        .dom(`${filters} button[aria-pressed="true"]`)
        .hasText(label, "the clicked filter stays selected");
      assert
        .dom(`${filters} button[aria-pressed="false"]`)
        .exists({ count: 3 }, "the other filters are explicitly unselected");
    }
  });

  test("searches the server and preserves filters through load more and refresh", async function (assert) {
    const requests = [];
    pretender.get("/blog-editor.json", (request) => {
      requests.push({ ...request.queryParams });
      return response({
        topics:
          request.queryParams.page === "1"
            ? [{ ...draft, id: 125, title: "Another matching draft" }]
            : [draft],
        more:
          request.queryParams.q === "workflow" &&
          request.queryParams.page !== "1",
      });
    });
    await visit("/blog-editor");
    await click(".blog-dashboard__filters button:nth-child(2)");
    await formKit(".blog-dashboard__search").field("q").fillIn("workflow");
    await formKit(".blog-dashboard__search").submit();
    assert.deepEqual(
      requests.at(-1),
      { filter: "drafts", q: "workflow" },
      "search is combined with the server-side status filter"
    );
    await click("[data-blog-load-more]");
    assert.deepEqual(
      requests.at(-1),
      { filter: "drafts", q: "workflow", page: "1" },
      "load more preserves the entire query"
    );
    assert
      .dom(".blog-dashboard__row")
      .exists({ count: 2 }, "additional matching entries are appended");
    assert
      .dom("[data-blog-load-more]")
      .doesNotExist("loading stops when there are no more matches");
    await click(".blog-dashboard__links button");
    assert.deepEqual(
      requests.at(-1),
      { filter: "drafts", q: "workflow" },
      "refresh keeps filters and returns to the first page"
    );
    assert
      .dom(".blog-dashboard__row")
      .exists({ count: 1 }, "refresh replaces previous pages");
  });
});
