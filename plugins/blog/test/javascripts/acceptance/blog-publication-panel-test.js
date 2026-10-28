import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
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
      featured: false,
      changes: [],
      edits_since_publish: 0,
      draft_updated_at: "2026-09-01T10:00:00Z",
      source_topic_id: 280,
      source_url: TOPIC_URL,
      preview_url: "/blog/preview/280",
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
    pretender.get("/blog/publications/280.json", () => response(publication));
  });

  test("publishes the current draft in one step", async function (assert) {
    pretender.post("/blog/publications/280/publish.json", (request) => {
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
      .dom(`${PANEL}__meta a`)
      .hasText(
        "blog.example.com/an-unfinished-story",
        "the future article address is shown"
      );
    assert
      .dom(`${PANEL}__publish`)
      .hasText("Publish", "publishing is the primary action");
    await click(`${PANEL}__publish`);
    assert
      .dom(".dialog-body")
      .includesText("stay private", "the privacy boundary is explained");
    await click(".dialog-footer .btn-primary");
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
    pretender.get("/blog/publications/280/changes.json", () =>
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
      .hasText("Changed: body, excerpt", "changed fields are listed");
    assert
      .dom(`${PANEL}__publish`)
      .hasText("Publish correction", "corrections are named explicitly");
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
    pretender.post("/blog/publications/280/submit.json", () => {
      publication = {
        ...publication,
        submitted_revision: {
          id: 7,
          preview_url: "/blog/preview/280?revision_id=7",
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
      .dom(`${PANEL}__pending`)
      .includesText("Revision 7 submitted", "the submission is confirmed");
    assert
      .dom(`${PANEL}__approve`)
      .doesNotExist("approval requires a publisher");
  });

  test("publishers approve and publish a submitted revision", async function (assert) {
    publication.submitted_revision = {
      id: 7,
      preview_url: "/blog/preview/280?revision_id=7",
    };
    pretender.post("/blog/publications/280/approve.json", (request) => {
      assert.step(
        `approve ${new URLSearchParams(request.requestBody).get("revision_id")}`
      );
      publication = {
        ...publication,
        approved_revision: publication.submitted_revision,
      };
      return response(publication);
    });
    pretender.post("/blog/publications/280/publish.json", (request) => {
      assert.step(
        `publish ${new URLSearchParams(request.requestBody).get("revision_id")}`
      );
      publication = {
        ...publication,
        status: "live",
        published: true,
        live: true,
        published_revision_id: 7,
      };
      return response(publication);
    });
    await visit(TOPIC_URL);
    assert
      .dom(`${PANEL}__pending a`)
      .hasAttribute(
        "href",
        "/blog/preview/280?revision_id=7",
        "the frozen revision can be previewed"
      );
    await click(`${PANEL}__approve`);
    assert.verifySteps(
      ["approve 7", "publish 7"],
      "only the submitted revision is approved and published"
    );
    assert
      .dom(`${PANEL}__pending`)
      .doesNotExist("the published revision is no longer pending");
  });

  test("schedules the current draft and allows cancellation", async function (assert) {
    pretender.post("/blog/publications/280/submit.json", () => {
      assert.step("submit");
      publication = {
        ...publication,
        submitted_revision: {
          id: 7,
          preview_url: "/blog/preview/280?revision_id=7",
        },
      };
      return response(publication);
    });
    pretender.post("/blog/publications/280/approve.json", () => {
      assert.step("approve");
      publication = {
        ...publication,
        approved_revision: publication.submitted_revision,
      };
      return response(publication);
    });
    pretender.post("/blog/publications/280/schedule.json", (request) => {
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
          preview_url: "/blog/preview/280?revision_id=7",
        },
      };
      return response(publication);
    });
    pretender.delete("/blog/publications/280/schedule.json", () => {
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
      .includesText("approved by eviltrout", "provenance is shown");
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
    pretender.get("/blog/publications/280/feedback.json", () =>
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
      })
    );
    await visit(TOPIC_URL);
    assert
      .dom(`${PANEL}__reviews-title`)
      .includesText("2 private feedback", "the feedback count is visible");
    assert
      .dom(`${PANEL}__reviews-title`)
      .includesText("1 active review link", "open links are counted");
    assert.dom(`${PANEL}__feedback`).doesNotExist("feedback loads on demand");
    await click(`${PANEL}__toggle-feedback`);
    assert.dom(`${PANEL}__feedback-entry`).exists({ count: 2 });
    assert
      .dom(`${PANEL}__feedback-entry:first-child`)
      .includesText("Anonymous reviewer", "missing names are labelled");
    assert
      .dom(`${PANEL}__feedback-entry:last-child`)
      .includesText("Ada", "reviewer names are shown")
      .includesText("Round one", "the review label is shown")
      .includesText("Article revision 1", "the reviewed revision is shown");
    assert
      .dom(`${PANEL}__feedback-entry:last-child script`)
      .doesNotExist("feedback is rendered as text");
    await click(`${PANEL}__toggle-feedback`);
    assert.dom(`${PANEL}__feedback`).doesNotExist("feedback collapses again");
  });

  test("saves article settings without publishing", async function (assert) {
    pretender.put("/blog/publications/280.json", (request) => {
      const data = new URLSearchParams(request.requestBody);
      assert.strictEqual(
        data.get("publication[excerpt]"),
        "A revised introduction",
        "the excerpt is saved"
      );
      publication = { ...publication, excerpt: "A revised introduction" };
      return response(publication);
    });
    await visit(TOPIC_URL);
    assert
      .dom(`${PANEL}__form`)
      .isNotVisible("settings are collapsed by default");
    await click(`${PANEL}__settings-toggle`);
    await formKit(`${PANEL}__form`)
      .field("excerpt")
      .fillIn("A revised introduction");
    await formKit(`${PANEL}__form`).submit();
    assert
      .dom(`${PANEL}__badge`)
      .hasText("Draft", "saving settings does not publish");
  });

  test("the public discussion topic points at the private working copy", async function (assert) {
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
      .dom(".blog-discussion-banner")
      .includesText(
        "which has unpublished changes",
        "pending corrections are mentioned"
      );
    assert
      .dom('.blog-discussion-banner a[href="/t/private-working-copy/281"]')
      .exists("the working copy is linked");
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
        preview_url: "/blog/preview/280?revision_id=9",
      },
    };
    await visit("/");
    await visit(TOPIC_URL);
    assert.dom(`${PANEL}__badge`).hasText("Scheduled");
    assert
      .dom(`${PANEL}__changed`)
      .includesText("body", "drift since the frozen revision is still listed");
  });
});
