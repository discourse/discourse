import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

const revisionResponse = {
  created_at: "2021-11-24T10:59:36.163Z",
  post_id: 419,
  previous_hidden: false,
  current_hidden: false,
  first_revision: 1,
  previous_revision: 1,
  current_revision: 2,
  next_revision: null,
  last_revision: 2,
  current_version: 2,
  version_count: 2,
  username: "bianca",
  display_username: "bianca",
  avatar_template: "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
  edit_reason: null,
  body_changes: {
    inline: '<div class="inline-diff"><p>Welcome to Discourse!</p</div>',
    side_by_side:
      '<div class="revision-content"><p>Welcome to Discourse!</p</div><div class="revision-content"><p>Welcome to Discourse!</p</div>',
    side_by_side_markdown:
      '<table class="markdown"><tr><td>Welcome to Discourse!</td><td>Welcome to Discourse!</td></tr></table>',
  },
  title_changes: {
    inline: '<div class="inline-diff"><div>Welcome to Discourse!</div></div>',
    side_by_side:
      '<div class="revision-content"><div>Welcome to Discourse!</div></div><div class="revision-content"><div>Welcome to Discourse!</div></div>',
  },
  user_changes: null,
  tags_changes: {
    previous: ["tag1", "tag2"],
    current: ["tag2", "tag3"],
  },
  wiki: false,
  can_edit: true,
};

acceptance("History Modal - authorized", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/posts/419/revisions/latest.json", () => {
      return helper.response(revisionResponse);
    });

    server.get("/posts/419/revisions/1.json", () => {
      return helper.response({
        ...revisionResponse,
        current_revision: 1,
        previous_revision: null,
      });
    });
  });

  test("edit post button", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article[data-post-id='419'] .edits button");
    assert
      .dom(".history-modal #revision-footer-buttons .edit-post")
      .exists("displays the edit post button on the latest revision");
  });

  test("edit post button - not last revision", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article[data-post-id='419'] .edits button");
    await click(".history-modal .previous-revision");
    assert
      .dom(".history-modal #revision-footer-buttons .edit-post")
      .doesNotExist(
        "hides the edit post button when not on the latest revision"
      );
  });

  test("previous revision button", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article[data-post-id='419'] .edits button");

    await click(".history-modal .previous-revision");

    assert.dom(".history-modal .previous-revision").isDisabled();
  });
});

acceptance("History Modal - anonymous", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/posts/419/revisions/latest.json", () => {
      return helper.response({ ...revisionResponse, can_edit: false });
    });
  });

  test("edit post button", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article[data-post-id='419'] .edits button");
    assert
      .dom(".history-modal #revision-footer-buttons .edit-post")
      .doesNotExist(
        "it should not display edit button when user cannot edit the post"
      );
  });
});

acceptance("History Modal - not found", function (needs) {
  needs.pretender((server, helper) => {
    const json = cloneJSON(topicFixtures["/t/280/1.json"]);
    json.post_stream.posts[0].version = 2;
    json.post_stream.posts[0].can_view_edit_history = true;

    server.get("/t/280.json", () => helper.response(json));
    server.get("/t/280/:post_number.json", () => {
      helper.response(json);
    });

    server.get("/posts/398/revisions/latest.json", () => {
      return helper.response(404, {
        errors: ["The requested URL or resource could not be found."],
        error_type: "not_found",
      });
    });
  });

  test("try to view a nonexistent revision", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article[data-post-id='398'] .edits button");

    assert.dom(".alert-error").exists();
    await click(".modal-close");

    assert
      .dom("article[data-post-id='398'] .edits button")
      .doesNotExist("it should refresh the post to hide the revisions button");
  });
});

acceptance("History Modal - revision visibility as staff", function (needs) {
  let hidden, unlisted, unlistFails, requests;

  needs.user();
  needs.hooks.beforeEach(() => {
    hidden = false;
    unlisted = false;
    unlistFails = false;
    requests = [];
  });
  needs.pretender((server, helper) => {
    const revision = () => ({
      ...revisionResponse,
      previous_hidden: hidden,
      unlisted,
      unlisted_revision_count: unlisted ? 1 : 0,
    });
    const change = (action, apply) => () => {
      requests.push(action);
      apply();
      return helper.response({});
    };

    server.get("/posts/419/revisions/latest.json", () =>
      helper.response(revision())
    );
    server.get("/posts/419/revisions/2.json", () =>
      helper.response(revision())
    );
    server.put("/posts/419/revisions/2/unlist", (request) =>
      unlistFails
        ? helper.response(422, { errors: ["Can't unlist this revision"] })
        : change("unlist", () => (unlisted = true))(request)
    );
    server.put(
      "/posts/419/revisions/2/relist",
      change("relist", () => (unlisted = false))
    );
    server.put(
      "/posts/419/revisions/2/hide",
      change("hide", () => {
        hidden = true;
        unlisted = false;
      })
    );
    server.put(
      "/posts/419/revisions/2/show",
      change("show", () => (hidden = false))
    );
  });

  async function chooseVisibility(visibility) {
    await click(".history-modal .revision-visibility__trigger");
    await click(`.history-modal [data-revision-visibility='${visibility}']`);
  }

  test("unlisting and relisting a revision", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article[data-post-id='419'] .edits button");

    assert
      .dom(".history-modal .revision-visibility__trigger")
      .hasText(i18n("post.revisions.visibility.listed.title"));
    assert
      .dom(".history-modal .revision-details__unlisted")
      .doesNotExist("doesn't mark a listed revision");

    await chooseVisibility("unlisted");

    assert
      .dom(".history-modal .revision-visibility__trigger")
      .hasText(i18n("post.revisions.visibility.unlisted.title"));
    assert
      .dom(".history-modal .revision-details__unlisted")
      .hasText(i18n("post.revisions.unlisted.label"), "marks it as unlisted");
    assert
      .dom(".history-modal .show-unlisted-revisions")
      .doesNotExist("doesn't offer staff the unlisted toggle");

    await chooseVisibility("listed");

    assert
      .dom(".history-modal .revision-details__unlisted")
      .doesNotExist("removes the marker once relisted");
    assert.deepEqual(requests, ["unlist", "relist"]);
  });

  test("only offers the other visibilities", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article[data-post-id='419'] .edits button");
    await click(".history-modal .revision-visibility__trigger");

    assert
      .dom(".history-modal [data-revision-visibility='listed']")
      .doesNotExist("doesn't offer the current visibility");
    assert.dom(".history-modal [data-revision-visibility='unlisted']").exists();
    assert.dom(".history-modal [data-revision-visibility='hidden']").exists();
    assert
      .dom(".history-modal .destroy-revision")
      .doesNotExist("doesn't offer to delete revisions by default");
  });

  test("unlisting a hidden revision", async function (assert) {
    hidden = true;

    await visit("/t/internationalization-localization/280");
    await click("article[data-post-id='419'] .edits button");

    assert
      .dom(".history-modal .revision-visibility__trigger")
      .hasText(i18n("post.revisions.visibility.hidden.title"));

    await chooseVisibility("unlisted");

    assert
      .dom(".history-modal .revision-visibility__trigger")
      .hasText(i18n("post.revisions.visibility.unlisted.title"));
    assert.deepEqual(
      requests,
      ["show", "unlist"],
      "shows the revision before unlisting it"
    );
  });

  test("unlisting a hidden revision fails after showing it", async function (assert) {
    hidden = true;
    unlistFails = true;

    await visit("/t/internationalization-localization/280");
    await click("article[data-post-id='419'] .edits button");
    await chooseVisibility("unlisted");

    assert.dom(".dialog-body").exists("reports the failure");
    assert
      .dom(".history-modal .revision-visibility__trigger")
      .hasText(
        i18n("post.revisions.visibility.listed.title"),
        "reflects the revision now being listed"
      );
  });
});

acceptance("History Modal - deleting revisions", function (needs) {
  needs.user();
  needs.settings({ can_permanently_delete: true });
  needs.pretender((server, helper) => {
    server.get("/posts/419/revisions/latest.json", () =>
      helper.response(revisionResponse)
    );
  });

  test("offers to delete all revisions from a listed revision", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article[data-post-id='419'] .edits button");
    await click(".history-modal .revision-visibility__trigger");

    assert
      .dom(".history-modal .destroy-revision")
      .hasText(i18n("post.revisions.controls.destroy"));
  });
});

acceptance("History Modal - unlisted revisions as a user", function (needs) {
  let unlistedRevisionCount;

  needs.user({ admin: false, moderator: false, staff: false });
  needs.hooks.beforeEach(() => (unlistedRevisionCount = 1));
  needs.pretender((server, helper) => {
    const listedRevision = (request) => ({
      ...revisionResponse,
      first_revision: 2,
      previous_revision: null,
      next_revision: request.queryParams.include_unlisted ? 3 : null,
      unlisted: false,
      unlisted_revision_count: unlistedRevisionCount,
    });

    server.get("/posts/419/revisions/latest.json", (request) =>
      helper.response(listedRevision(request))
    );
    server.get("/posts/419/revisions/2.json", (request) =>
      helper.response(listedRevision(request))
    );
    server.get("/posts/419/revisions/3.json", () =>
      helper.response({
        ...revisionResponse,
        first_revision: 2,
        previous_revision: 2,
        current_revision: 3,
        last_revision: 3,
        unlisted: true,
        unlisted_revision_count: unlistedRevisionCount,
      })
    );
  });

  test("showing all edits", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article[data-post-id='419'] .edits button");

    assert
      .dom(".history-modal .revision-visibility__trigger")
      .doesNotExist("doesn't offer staff actions");
    assert
      .dom(".history-modal .next-revision")
      .isDisabled("skips the unlisted revision");

    await click(".history-modal .show-unlisted-revisions");

    assert
      .dom(".history-modal .show-unlisted-revisions")
      .hasAria("checked", "true", "turns the toggle on");

    await click(".history-modal .next-revision");

    assert
      .dom(".history-modal .revision-details__unlisted")
      .exists("marks the unlisted revision");
  });

  test("without unlisted revisions", async function (assert) {
    unlistedRevisionCount = 0;

    await visit("/t/internationalization-localization/280");
    await click("article[data-post-id='419'] .edits button");

    assert
      .dom(".history-modal .show-unlisted-revisions")
      .doesNotExist("doesn't offer the unlisted toggle");
  });
});
