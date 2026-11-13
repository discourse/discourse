import { click, fillIn as typeInto, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const TOPIC_URL = "/t/internationalization-localization/280";
const PANEL = ".blog-publication-panel";

acceptance("Blog publication panel", function (needs) {
  needs.user({ admin: true });
  needs.settings({ blog_enabled: true });

  let publication;

  needs.hooks.beforeEach(() => {
    publication = {
      id: 280,
      role: "draft",
      status: "draft",
      title: "An unfinished story",
      path: "/an-unfinished-story",
      url: "https://blog.example.com/an-unfinished-story",
      excerpt: "",
      meta_description: "",
      canonical_url: "",
      featured: false,
      changes: [],
      edits_since_publish: 0,
      draft_updated_at: "2026-09-01T10:00:00Z",
      source_topic_id: 280,
      source_url: TOPIC_URL,
      preview_url: "/blog-editor/preview/280",
      published: false,
      live: false,
      draft: true,
      can_publish: true,
      review_feedback_count: 0,
      active_review_links: 0,
      submitted_revision: null,
      approved_revision: null,
      scheduled_revision: null,
      scheduled_at: null,
      schedule_error: "",
    };
    pretender.get("/t/280.json", () => {
      const topic = cloneJSON(topicFixtures["/t/280/1.json"]);
      topic.blog_publication = publication;
      return response(topic);
    });
    pretender.get("/blog-editor/publications/280.json", () =>
      response(publication)
    );
  });

  test("publishes the current draft in one step", async function (assert) {
    publication.active_review_links = 2;
    pretender.post("/blog-editor/publications/280/publish.json", (request) => {
      assert.false(
        new URLSearchParams(request.requestBody).has("revision_id"),
        "the current draft is published without a frozen revision id"
      );
      publication = {
        ...publication,
        status: "live",
        published: true,
        live: true,
        published_revision_id: 7,
        last_published_at: "2026-09-02T10:00:00Z",
      };
      return response(publication);
    });
    await visit(TOPIC_URL);
    assert
      .dom(`${PANEL}__badge`)
      .hasText("Draft", "a never-published draft is labelled");
    assert
      .dom(`${PANEL}__future-url`)
      .hasText(
        "blog.example.com/an-unfinished-story",
        "the future article address is shown"
      );
    assert
      .dom(`${PANEL}__meta a`)
      .doesNotExist("the future address is not linked before it exists");
    assert
      .dom(`${PANEL}__publish`)
      .hasText("Publish now", "publishing is the primary action");
    const toasts = this.owner.lookup("service:toasts");
    const toastSpy = sinon.spy(toasts.success);
    sinon.replaceGetter(toasts, "success", () => toastSpy);
    await click(`${PANEL}__publish`);
    assert
      .dom(".dialog-body")
      .includesText("stay private", "the privacy boundary is explained");
    await click(".dialog-footer .btn-primary");
    assert.true(
      toastSpy.calledWithMatch({
        data: { message: sinon.match("Its 2 preview links were closed.") },
      }),
      "closing the draft's preview links is announced"
    );
    assert
      .dom(`${PANEL}__badge`)
      .hasText("Live", "the panel reflects the release");
    assert
      .dom(`${PANEL}__view-live`)
      .hasAttribute("href", publication.url, "the live article is linked");
    assert
      .dom(`${PANEL}__publish`)
      .doesNotExist("a live article without edits has nothing to publish");
    assert
      .dom(`${PANEL}__options`)
      .exists("withdrawal stays reachable from the live state");
  });

  test("explains pending changes and shows the diff on demand", async function (assert) {
    publication = {
      ...publication,
      status: "changes_pending",
      published: true,
      live: true,
      published_revision_id: 6,
      last_published_at: "2026-09-02T10:00:00Z",
      changes: ["body", "excerpt"],
      edits_since_publish: 3,
    };
    pretender.get("/blog-editor/publications/280/changes.json", () =>
      response({
        title_diff_html: null,
        diff_html:
          '<div class="inline-diff"><p>Hello <ins>world</ins></p></div>',
      })
    );
    await visit(TOPIC_URL);
    assert
      .dom(`${PANEL}__badge`)
      .hasText("Changes pending", "drift from the live revision is flagged");
    assert
      .dom(`${PANEL}__meta`)
      .includesText("3 edits since", "the amount of drift is shown");
    assert
      .dom(`${PANEL}__changed`)
      .hasText("Changed: Body, excerpt", "changed fields are listed");
    assert
      .dom(`${PANEL}__publish`)
      .hasText("Publish changes", "publishing edits is named explicitly");
    await click(`${PANEL}__toggle-diff`);
    assert
      .dom(`${PANEL}__diff ins`)
      .hasText("world", "the server diff is rendered inline");
    await click(`${PANEL}__menu-trigger`);
    assert
      .dom(`${PANEL}__unpublish`)
      .exists("published articles can be withdrawn from the menu");
  });

  test("contributors submit for approval without publisher actions", async function (assert) {
    publication.can_publish = false;
    pretender.post("/blog-editor/publications/280/submit.json", () => {
      publication = {
        ...publication,
        awaiting_approval: true,
        submitted_revision: {
          id: 7,
          preview_url: "/blog-editor/preview/280?revision_id=7",
        },
      };
      return response(publication);
    });
    await visit(TOPIC_URL);
    assert
      .dom(`${PANEL}__publish`)
      .hasText("Submit for approval", "contributors cannot publish");
    assert
      .dom(`${PANEL}__menu-trigger`)
      .doesNotExist("publisher options are not offered");
    await click(`${PANEL}__publish`);
    assert
      .dom(`${PANEL}__badge`)
      .hasText("Needs approval", "the submission replaces the status");
  });

  test("publishers see a pending submission without a separate approval step", async function (assert) {
    publication.awaiting_approval = true;
    publication.submitted_revision = {
      id: 7,
      preview_url: "/blog-editor/preview/280?revision_id=7",
    };
    await visit(TOPIC_URL);
    assert
      .dom(`${PANEL}__badge`)
      .hasText("Needs approval", "the request is visible to publishers");
    assert
      .dom(`${PANEL}__publish`)
      .exists("publishing the draft approves it in one step");
  });

  test("schedules the current draft and allows cancellation", async function (assert) {
    pretender.post("/blog-editor/publications/280/submit.json", () => {
      assert.step("submit");
      publication = {
        ...publication,
        submitted_revision: {
          id: 7,
          preview_url: "/blog-editor/preview/280?revision_id=7",
        },
      };
      return response(publication);
    });
    pretender.post("/blog-editor/publications/280/approve.json", () => {
      assert.step("approve");
      publication = {
        ...publication,
        approved_revision: publication.submitted_revision,
      };
      return response(publication);
    });
    pretender.post("/blog-editor/publications/280/schedule.json", (request) => {
      const data = new URLSearchParams(request.requestBody);
      assert.step(`schedule ${data.get("revision_id")}`);
      assert.strictEqual(
        data.get("scheduled_at"),
        new Date("2030-04-05T14:30").toISOString(),
        "local time is sent as an unambiguous UTC instant"
      );
      publication = {
        ...publication,
        status: "scheduled",
        scheduled_at: data.get("scheduled_at"),
        scheduled_revision: {
          id: 7,
          approved_by: "eviltrout",
          preview_url: "/blog-editor/preview/280?revision_id=7",
        },
      };
      return response(publication);
    });
    pretender.delete("/blog-editor/publications/280/schedule.json", () => {
      assert.step("cancel");
      publication = {
        ...publication,
        status: "draft",
        scheduled_at: null,
        scheduled_revision: null,
      };
      return response(204);
    });
    await visit(TOPIC_URL);
    await click(`${PANEL}__menu-trigger`);
    await click(`${PANEL}__menu-schedule`);
    await formKit(".blog-schedule form")
      .field("scheduled_at")
      .fillIn("2030-04-05T14:30");
    await formKit(".blog-schedule form").submit();
    assert.verifySteps(
      ["submit", "approve", "schedule 7"],
      "scheduling freezes and approves the current draft first"
    );
    assert.dom(".blog-schedule").doesNotExist("the dialog closes on success");
    assert
      .dom(`${PANEL}__badge`)
      .hasText("Scheduled", "the scheduled release is shown");
    assert
      .dom(`${PANEL}__meta`)
      .includesText("Approved by eviltrout", "provenance is shown");
    await click(`${PANEL}__cancel-schedule`);
    assert.verifySteps(["cancel"], "the schedule can be cancelled");
    assert
      .dom(`${PANEL}__badge`)
      .hasText("Draft", "cancellation returns to the draft state");
  });

  test("reads private review feedback inline", async function (assert) {
    publication = {
      ...publication,
      review_feedback_count: 2,
      active_review_links: 1,
    };
    pretender.get("/blog-editor/publications/280/feedback.json", () =>
      response({
        feedback: [
          {
            id: 2,
            name: "",
            email: "",
            message: "Loving it but the colours hurt.",
            created_at: "2026-09-03T10:00:00Z",
            review: { id: 9, label: "", post_version: 3, revoked_at: null },
          },
          {
            id: 1,
            name: "Ada",
            email: "ada@example.com",
            message: "<script>alert(1)</script> Tighten the introduction.",
            created_at: "2026-09-02T10:00:00Z",
            review: {
              id: 8,
              label: "Round one",
              post_version: 1,
              revoked_at: "2026-09-02T12:00:00Z",
            },
          },
        ],
        more: false,
        latest_version: 3,
      })
    );
    await visit(TOPIC_URL);
    assert
      .dom(`${PANEL}__reviews-title`)
      .includesText("Show feedback", "feedback can be opened");
    assert.dom(`${PANEL}__feedback`).doesNotExist("feedback loads on demand");
    await click(`${PANEL}__toggle-feedback`);
    assert
      .dom(`${PANEL}__feedback-entry`)
      .exists({ count: 1 }, "only feedback on the newest version is shown");
    assert
      .dom(`${PANEL}__feedback-entry`)
      .includesText("Anonymous reviewer", "missing names are labelled")
      .includesText("Untitled review link", "unlabelled links are named");
    assert
      .dom(`${PANEL}__toggle-older-feedback`)
      .hasText("Show 1 earlier response", "older feedback is offered");
    await click(`${PANEL}__toggle-older-feedback`);
    assert.dom(`${PANEL}__feedback-entry`).exists({ count: 2 });
    assert
      .dom(`${PANEL}__older-feedback ${PANEL}__feedback-entry`)
      .includesText("Ada", "reviewer names are shown")
      .includesText("Round one", "the review label is shown");
    assert
      .dom(`${PANEL}__older-feedback script`)
      .doesNotExist("feedback is rendered as text");
    assert
      .dom(`${PANEL}__toggle-older-feedback`)
      .hasText("Hide earlier responses", "older feedback can be hidden again");
    await click(`${PANEL}__toggle-feedback`);
    assert.dom(`${PANEL}__feedback`).doesNotExist("feedback collapses again");
  });

  test("starts a new feedback round after publishing", async function (assert) {
    publication = {
      ...publication,
      review_feedback_count: 1,
      last_published_at: "2026-09-05T10:00:00Z",
    };
    pretender.get("/blog-editor/publications/280/feedback.json", () =>
      response({
        feedback: [
          {
            id: 1,
            name: "Ada",
            email: "",
            message: "Tighten the introduction.",
            created_at: "2026-09-02T10:00:00Z",
            review: { id: 8, label: "Round one", post_version: 1 },
          },
        ],
        more: false,
        latest_version: 1,
      })
    );
    await visit(TOPIC_URL);
    await click(`${PANEL}__toggle-feedback`);
    assert
      .dom(`${PANEL}__no-new-feedback`)
      .hasText(
        "No new feedback since the last publish.",
        "feedback on the published text is not presented as new"
      );
    assert
      .dom(`${PANEL}__feedback-notice`)
      .doesNotExist("the privacy note waits until feedback is shown");
    assert
      .dom(`${PANEL}__toggle-older-feedback`)
      .hasText("Show 1 earlier response");
    await click(`${PANEL}__toggle-older-feedback`);
    assert
      .dom(`${PANEL}__older-feedback ${PANEL}__feedback-entry`)
      .includesText("Ada", "earlier feedback stays available");
    assert
      .dom(`${PANEL}__feedback-notice`)
      .doesNotExist("expanding earlier feedback does not shift the list");
  });

  test("rechecks its status after the title is edited inline", async function (assert) {
    publication = {
      ...publication,
      status: "live",
      published: true,
      live: true,
      draft: false,
      published_revision_id: 7,
    };
    await visit(TOPIC_URL);
    assert.dom(`${PANEL}__badge`).hasText("Live");

    publication = {
      ...publication,
      status: "changes_pending",
      changes: ["title"],
    };
    await click("#topic-title .d-icon-pencil");
    await typeInto("#edit-title", "A sharper title for the article");
    await click("#topic-title .submit-edit");
    assert
      .dom(`${PANEL}__badge`)
      .hasText("Changes pending", "the panel updates without a reload");
  });

  test("saves article settings without publishing", async function (assert) {
    publication = {
      ...publication,
      cover_upload_id: 12,
      cover_url: "/images/discourse-logo-sketch.png",
      co_authors: ["ada", "bob"],
    };
    pretender.put("/blog-editor/publications/280.json", (request) => {
      const data = new URLSearchParams(request.requestBody);
      assert.strictEqual(
        data.get("publication[excerpt]"),
        "A revised introduction",
        "the excerpt is saved"
      );
      assert.strictEqual(
        data.get("publication[meta_description]"),
        "A summary for search engines",
        "the meta description is saved"
      );
      assert.strictEqual(
        data.get("publication[canonical_url]"),
        "https://example.com/original",
        "the canonical URL is saved"
      );
      assert.strictEqual(
        data.get("publication[cover_upload_id]"),
        "12",
        "the cover is saved by its upload id"
      );
      assert.strictEqual(
        data.get("publication[cover_alt]"),
        "A lighthouse at dusk",
        "the cover alt text is saved"
      );
      assert.false(
        data.has("publication[cover_url]"),
        "the cover preview URL is not sent"
      );
      assert.strictEqual(
        data.get("publication[co_authors]"),
        "ada,bob",
        "co-authors are sent as one list of usernames"
      );
      publication = { ...publication, excerpt: "A revised introduction" };
      return response(publication);
    });
    await visit(TOPIC_URL);
    assert
      .dom(`${PANEL}__form`)
      .isNotVisible("settings are collapsed by default");
    await click(`${PANEL}__settings-toggle`);
    assert
      .dom(`${PANEL}__form [name="canonical_url"]`)
      .hasAttribute(
        "placeholder",
        "https://blog.example.com/an-unfinished-story",
        "a blank canonical URL shows the article's own address"
      );
    await formKit(`${PANEL}__form`)
      .field("excerpt")
      .fillIn("A revised introduction");
    await formKit(`${PANEL}__form`)
      .field("cover_alt")
      .fillIn("A lighthouse at dusk");
    await formKit(`${PANEL}__form`)
      .field("meta_description")
      .fillIn("A summary for search engines");
    await formKit(`${PANEL}__form`)
      .field("canonical_url")
      .fillIn("https://example.com/original");
    await formKit(`${PANEL}__form`).submit();
    assert
      .dom(`${PANEL}__badge`)
      .hasText("Draft", "saving settings does not publish");
  });

  test("the public discussion topic explains where replies appear", async function (assert) {
    publication = {
      ...publication,
      role: "discussion",
      status: "changes_pending",
      published: true,
      live: true,
      draft_correction: true,
      changes: ["body"],
      source_url: "/t/private-working-copy/281",
    };
    await visit(TOPIC_URL);
    assert.dom(PANEL).doesNotExist("the full panel stays on the working copy");
    assert
      .dom(".blog-discussion-banner__text")
      .hasText(
        "This is the public discussion, replies here will appear on the blog.",
        "the banner explains where replies appear"
      );
    assert
      .dom('.blog-discussion-banner a[href="/t/private-working-copy/281"]')
      .doesNotExist("Edit privately is the way into the working copy");
    assert
      .dom(".blog-discussion-banner__edit")
      .hasText("Edit privately", "editing is redirected to the working copy");
  });

  test("a public topic that is not on the blog offers to prepare a working copy", async function (assert) {
    publication = {
      ...publication,
      role: "discussion",
      source_topic_id: null,
      source_url: null,
    };
    await visit(TOPIC_URL);
    assert.dom(PANEL).doesNotExist("no publishing actions on a public topic");
    assert
      .dom(".blog-discussion-banner")
      .includesText("This topic is not on the blog", "the state is explained")
      .includesText("prepare changes", "the next step is explained");
    assert.dom(".blog-discussion-banner__edit").exists();
  });

  test("shows a withdrawn article and lists pending changes while scheduled", async function (assert) {
    publication = {
      ...publication,
      status: "unpublished",
      published: false,
      published_revision_id: 7,
      last_published_at: "2026-09-02T10:00:00Z",
    };
    await visit(TOPIC_URL);
    assert.dom(`${PANEL}__badge`).hasText("Unpublished");
    assert
      .dom(`${PANEL}__meta`)
      .includesText("discussion stays open", "the discussion is unaffected");
    assert.dom(`${PANEL}__changes`).doesNotExist();

    publication = {
      ...publication,
      status: "scheduled",
      published: true,
      changes: ["body"],
      scheduled_at: "2030-01-01T09:00:00Z",
      scheduled_revision: {
        id: 9,
        approved_by: "eviltrout",
        preview_url: "/blog-editor/preview/280?revision_id=9",
      },
    };
    await visit("/");
    await visit(TOPIC_URL);
    assert.dom(`${PANEL}__badge`).hasText("Scheduled");
    assert
      .dom(`${PANEL}__changed`)
      .includesText("Body", "drift since the frozen revision is still listed");
  });
});
