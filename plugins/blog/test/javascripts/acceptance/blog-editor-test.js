import {
  click,
  currentURL,
  fillIn,
  findAll,
  select,
  visit,
  waitUntil,
} from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import stubIntersectionObserver from "discourse/tests/helpers/stub-intersection-observer";
import {
  disableLoadMoreObserver,
  enableLoadMoreObserver,
} from "discourse/ui-kit/d-load-more";

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
      status: "draft",
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
      status: "live",
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
          pages: [draft, published].filter((topic) => topic.page),
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
    await select(".d-filter-controls__dropdown", "drafts");
    assert.dom('[data-topic-id="123"]').exists("private drafts are shown");
    assert
      .dom('[data-topic-id="124"]')
      .doesNotExist("published articles are filtered out");
    await select(".d-filter-controls__dropdown", "published");
    assert.dom('[data-topic-id="124"]').exists("published articles are shown");
    assert
      .dom('[data-topic-id="123"]')
      .doesNotExist("private drafts are filtered out");
    await select(".d-filter-controls__dropdown", "unpublished");
    assert
      .dom(".blog-dashboard__row")
      .doesNotExist("unpublished filtering can return an empty result");
    assert
      .dom(".d-filter-controls__no-results")
      .includesText(
        "No matching articles",
        "filtered lists explain the result"
      );
    assert
      .dom(".empty-state")
      .doesNotExist("the no-articles state is only for an empty blog");
    await click(".d-filter-controls__no-results .btn");
    assert
      .dom(".blog-dashboard__row")
      .exists({ count: 2 }, "resetting the filters lists everything again");
  });

  test("marks standalone pages and filters them", async function (assert) {
    published = { ...published, page: true };
    await visit("/blog-editor");
    assert
      .dom('[data-topic-id="124"] .blog-dashboard__page-badge')
      .hasText("Page", "standalone pages are marked");
    assert
      .dom('[data-topic-id="123"] .blog-dashboard__page-badge')
      .doesNotExist("articles are not");
    await select(".d-filter-controls__dropdown", "pages");
    assert.dom('[data-topic-id="124"]').exists("pages are shown");
    assert
      .dom('[data-topic-id="123"]')
      .doesNotExist("articles are filtered out");
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
      status: "changes_pending",
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
      .hasText("Live", "edits do not change the article's own state");
    assert
      .dom('[data-topic-id="124"] .blog-dashboard__pending')
      .hasText("Edits pending", "unpublished edits are shown separately");
    assert
      .dom('[data-topic-id="123"] .blog-dashboard__status')
      .hasText("Draft", "never-published articles are drafts");
    assert
      .dom('[data-topic-id="123"] .blog-dashboard__status')
      .doesNotHaveClass("--success", "drafts use the neutral status style");
  });

  test("shows a submitted draft's approval request beside its state", async function (assert) {
    draft = { ...draft, awaiting_approval: true };
    await visit("/blog-editor");
    assert
      .dom('[data-topic-id="123"] .blog-dashboard__status')
      .hasText("Draft", "a submitted draft is still a draft");
    assert
      .dom('[data-topic-id="123"] .blog-dashboard__pending')
      .hasText("Needs approval");
    assert
      .dom('[data-topic-id="124"] .blog-dashboard__status')
      .hasText("Live")
      .hasClass("--success", "live articles use the success status style");
    assert
      .dom('[data-topic-id="124"] .blog-dashboard__pending')
      .doesNotExist("articles without pending work show one status");
  });

  test("shows submitted edits on a live article", async function (assert) {
    published = {
      ...published,
      status: "changes_pending",
      awaiting_approval: true,
    };
    await visit("/blog-editor");
    assert
      .dom('[data-topic-id="124"] .blog-dashboard__status')
      .hasText("Live", "the article stays live while edits wait");
    assert
      .dom('[data-topic-id="124"] .blog-dashboard__pending')
      .hasText("Edits need approval");
  });

  test("lists status, publication date, replies, and row actions", async function (assert) {
    published = {
      ...published,
      discussion_url: "/t/live-article/200",
      scheduled_at: "2026-10-01T10:00:00.000Z",
      status: "scheduled",
    };
    await visit("/blog-editor");
    assert
      .dom('[data-topic-id="124"] .blog-dashboard__status')
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

  test("offers page actions in the header", async function (assert) {
    await visit("/blog-editor");
    assert
      .dom(".d-page-header__actions .btn-primary")
      .hasText("New draft", "starting a draft is the primary action");
    await click(".blog-dashboard__page-actions");
    assert
      .dom(".blog-dashboard__visit-blog")
      .hasAttribute("href", "https://blog.example.com", "the blog is linked");
    assert
      .dom(".blog-dashboard__appearance")
      .exists("admins can reach the blog appearance settings");
  });

  test("keeps filters in the URL and restores them on reload", async function (assert) {
    const requests = [];
    pretender.get("/blog-editor.json", (request) => {
      requests.push({ ...request.queryParams });
      return response({ topics: [draft] });
    });
    await visit("/blog-editor?status=published&q=story");
    assert.deepEqual(
      requests[0],
      { filter: "published", q: "story" },
      "the first request uses the filters from the URL"
    );
    assert
      .dom(".d-filter-controls__dropdown")
      .hasValue("published", "the status filter is restored");
    assert
      .dom(".d-filter-controls__input")
      .hasValue("story", "the search is restored");

    await select(".d-filter-controls__dropdown", "drafts");
    assert.strictEqual(
      currentURL(),
      "/blog-editor?status=drafts&q=story",
      "changing the status updates the URL"
    );
  });

  test("ignores an unknown status in the URL", async function (assert) {
    const requests = [];
    pretender.get("/blog-editor.json", (request) => {
      requests.push({ ...request.queryParams });
      return response({ topics: [draft] });
    });
    await visit("/blog-editor?status=banana");
    assert.strictEqual(
      requests[0].filter,
      "all",
      "an unknown status falls back to all articles"
    );
    assert.dom(".d-filter-controls__dropdown").hasValue("all");
  });

  test("searches the server and preserves filters through load more", async function (assert) {
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
    enableLoadMoreObserver();
    const observations = stubIntersectionObserver();
    const scrollToEnd = () =>
      observations
        .findLast(({ element }) =>
          element.closest(".blog-dashboard__load-more")
        )
        .trigger();

    try {
      await visit("/blog-editor");
      await select(".d-filter-controls__dropdown", "drafts");
      await fillIn(".d-filter-controls__input", "workflow");
      assert.deepEqual(
        requests.at(-1),
        { filter: "drafts", q: "workflow" },
        "search is combined with the server-side status filter"
      );

      await scrollToEnd();
      await waitUntil(() => requests.some((request) => request.page === "1"));
      assert.deepEqual(
        requests.at(-1),
        { filter: "drafts", q: "workflow", page: "1" },
        "scrolling to the end loads the next page with the entire query"
      );
      assert
        .dom(".blog-dashboard__row")
        .exists({ count: 2 }, "additional matching entries are appended");

      const requestCount = requests.length;
      await scrollToEnd();
      assert.strictEqual(
        requests.length,
        requestCount,
        "loading stops when there are no more matches"
      );
    } finally {
      disableLoadMoreObserver();
    }
  });

  test("shows an empty state when there are no articles at all", async function (assert) {
    pretender.get("/blog-editor.json", () => response({ topics: [] }));
    await visit("/blog-editor");
    assert.dom(".empty-state").exists("an empty blog explains itself");
    assert
      .dom(".d-filter-controls__no-results")
      .doesNotExist("there is nothing to reset");
  });
});

acceptance("Blog composer", function (needs) {
  needs.user({ admin: true, moderator: false });
  needs.settings({
    blog_enabled: true,
    blog_category: 3,
    blog_drafts_category: 10,
    min_topic_title_length: 15,
  });
  needs.pretender((server, helper) => {
    server.get("/blog-editor.json", () =>
      helper.response({ topics: [], blog_url: "https://blog.example.com" })
    );
  });

  test("starts a draft in one click with a single blog", async function (assert) {
    await visit("/blog-editor");
    await click(".d-page-header__actions .btn-primary");

    assert.dom("#reply-control .d-editor").exists("the composer opens");
    assert.strictEqual(
      this.owner.lookup("service:composer").model.blogId,
      null,
      "the draft belongs to the only blog"
    );
  });

  test("accepts a short title for a page", async function (assert) {
    await visit("/blog-editor");
    await click(".d-page-header__actions .btn-primary");
    await fillIn("#reply-title", "Contact");
    await click(".submit-panel .create");

    assert
      .dom(".title-input .popup-tip.bad")
      .doesNotExist("a draft title can be as short as Contact");
    assert
      .dom(".d-editor-textarea-wrapper .popup-tip.bad")
      .exists("the composer still validated the draft");
  });
});

acceptance("Blog composer without a drafts category", function (needs) {
  needs.user({ admin: true, moderator: false });
  needs.settings({
    blog_enabled: true,
    blog_category: "",
    blog_drafts_category: "",
    min_topic_title_length: 15,
  });

  let draftsCategoryRequests;

  needs.hooks.beforeEach(() => {
    draftsCategoryRequests = 0;
  });

  needs.pretender((server, helper) => {
    server.get("/blog-editor.json", () =>
      helper.response({ topics: [], blog_url: "https://blog.example.com" })
    );
    server.post("/blog-editor/drafts-category.json", () => {
      draftsCategoryRequests++;
      return helper.response({
        id: 900,
        name: "Blog drafts",
        slug: "blog-drafts",
        color: "0088CC",
        text_color: "FFFFFF",
        read_restricted: true,
        permission: 1,
      });
    });
  });

  test("creates the drafts category when the first draft is started", async function (assert) {
    await visit("/blog-editor");
    await click(".d-page-header__actions .btn-primary");
    assert.strictEqual(
      selectKit(".category-chooser").header().value(),
      "900",
      "the composer opens in the new drafts category"
    );

    await click("#reply-control .discard-button");
    await click(".d-page-header__actions .btn-primary");
    assert.strictEqual(
      draftsCategoryRequests,
      1,
      "a known drafts category is not requested again"
    );

    await fillIn("#reply-title", "Contact");
    await click(".submit-panel .create");
    assert
      .dom(".title-input .popup-tip.bad")
      .doesNotExist("the new category accepts a short article title");
  });
});

acceptance("Blog editor with several blogs", function (needs) {
  needs.user({ admin: true, moderator: false });
  needs.settings({
    blog_enabled: true,
    blog_drafts_category: 10,
  });
  needs.site({
    blogs: [
      {
        id: 1,
        name: "The blog",
        is_default: true,
        base_url: "https://blog.example.com",
        category_id: 3,
        path_format: "/{slug}",
      },
      {
        id: 2,
        name: "Engineering",
        is_default: false,
        base_url: "https://blog.example.com/blog/engineering",
        category_id: 4,
        path_format: "/{year}/{slug}",
      },
    ],
  });

  let requests;

  needs.hooks.beforeEach(() => {
    requests = [];
  });

  needs.pretender((server, helper) => {
    server.get("/blog-editor.json", (request) => {
      requests.push({ ...request.queryParams });
      return helper.response({
        topics: [],
        blog_url: "https://blog.example.com",
      });
    });
  });

  test("filters the list by blog and keeps the choice in the URL", async function (assert) {
    await visit("/blog-editor?blog=2");
    assert.strictEqual(
      requests[0].blog,
      "2",
      "the first request uses the blog from the URL"
    );
    assert
      .dom(".d-filter-controls__dropdown--blog")
      .hasValue("2", "the blog filter is restored");

    await select(".d-filter-controls__dropdown--blog", "1");
    assert.strictEqual(
      requests.at(-1).blog,
      "1",
      "choosing a blog reloads its articles"
    );
    assert.true(
      currentURL().includes("blog=1"),
      "the chosen blog is kept in the URL"
    );
  });

  test("ignores a blog the site does not have", async function (assert) {
    await visit("/blog-editor?blog=99");
    assert.false(
      "blog" in requests[0],
      "an unknown blog falls back to all blogs"
    );
  });

  test("starts a new draft on the blog chosen from the menu", async function (assert) {
    await visit("/blog-editor");
    await click(".blog-dashboard__new-draft");

    assert
      .dom(".blog-dashboard__new-draft-blog")
      .exists({ count: 2 }, "every blog is offered");
    assert
      .dom(".blog-dashboard__new-draft-blog")
      .hasText("The blog", "the default blog comes first");

    await click(findAll(".blog-dashboard__new-draft-blog")[1]);
    assert.strictEqual(
      this.owner.lookup("service:composer").model.blogId,
      2,
      "the draft is created for the chosen blog"
    );
  });

  test("leaves the blog filter out of new drafts", async function (assert) {
    await visit("/blog-editor?blog=2");
    await click(".blog-dashboard__new-draft");
    await click(".blog-dashboard__new-draft-blog");

    assert.strictEqual(
      this.owner.lookup("service:composer").model.blogId,
      null,
      "choosing the default blog records no blog, whatever the filter shows"
    );
  });
});
