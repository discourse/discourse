import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

const revisionResponse = {
  created_at: "2021-11-24T10:59:36.163Z",
  post_id: 419,
  previous_hidden: true,
  current_hidden: false,
  first_revision: 2,
  previous_revision: 4,
  current_revision: 5,
  next_revision: null,
  last_revision: 5,
  current_version: 4,
  version_count: 4,
  username: "bianca",
  avatar_template: "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
  body_changes: null,
};

const publicCurrentComparison = {
  from_version: 2,
  to_version: 5,
  body_changes: {
    inline:
      '<div class="inline-diff"><p>Bob <del>is</del><ins>was</ins> here</p></div>',
    side_by_side:
      '<div class="revision-content"><p>Bob is here</p></div><div class="revision-content"><p>Bob was here</p></div>',
    side_by_side_markdown:
      '<table class="markdown"><tr><td>Bob is here</td><td>Bob was here</td></tr></table>',
  },
};

const comparisonSelector = ".revision__public-current-comparison";

acceptance("History Modal - public current comparison", function (needs) {
  let comparison;

  needs.hooks.beforeEach(() => {
    comparison = cloneJSON(publicCurrentComparison);
  });

  needs.user({ admin: false, moderator: false, staff: false });
  needs.pretender((server, helper) => {
    const topic = cloneJSON(topicFixtures["/t/280/1.json"]);
    const post = topic.post_stream.posts.find(({ id }) => id === 419);
    post.version = 5;
    post.can_view_edit_history = true;

    server.get("/t/280.json", () => helper.response(topic));
    server.get("/t/280/:post_number.json", () => helper.response(topic));

    const lastRevision = () => ({
      ...revisionResponse,
      public_current_comparison: comparison,
    });
    server.get("/posts/419/revisions/latest.json", () =>
      helper.response(lastRevision())
    );
    server.get("/posts/419/revisions/5.json", () =>
      helper.response(lastRevision())
    );
    server.get("/posts/419/revisions/4.json", () =>
      helper.response({
        ...revisionResponse,
        previous_hidden: true,
        previous_revision: 2,
        current_revision: 4,
        current_version: 3,
        next_revision: 5,
        body_changes: null,
      })
    );
  });

  test("labels the public comparison separately from the suppressed historical edit", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article[data-post-id='419'] .edits button");

    assert
      .dom(".revision__hidden-notice")
      .hasText(
        i18n("post.revisions.diff_hidden"),
        "the historical edit remains hidden"
      );
    assert
      .dom("#revisions > .body-diff")
      .doesNotExist("the summary does not replace the hidden historical diff");
    assert
      .dom(`${comparisonSelector} .alert`)
      .hasText(
        i18n("post.revisions.public_current_comparison", { from: 2, to: 5 }),
        "the summary identifies its endpoints and explains the omitted intervening changes"
      );
    assert
      .dom(`${comparisonSelector} .revision-details__user`)
      .doesNotExist("the aggregate comparison has no editor attribution");
    assert
      .dom(`${comparisonSelector} .body-diff`)
      .includesText("Bob is here", "the last accessible body is shown")
      .includesText("Bob was here", "the current public body is shown");
  });

  test("switches the public comparison between all diff modes without revealing the historical edit", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article[data-post-id='419'] .edits button");

    assert
      .dom(`${comparisonSelector} .revision-content`)
      .exists({ count: 2 }, "the comparison starts in side-by-side mode");

    await click(".history-modal .inline-mode");

    assert
      .dom(`${comparisonSelector} del`)
      .hasText("is", "inline mode marks the removed text");
    assert
      .dom(`${comparisonSelector} ins`)
      .hasText("was", "inline mode marks the added text");

    await click(".history-modal .side-by-side-markdown-mode");

    assert
      .dom(`${comparisonSelector} table.markdown`)
      .exists("markdown mode renders the public comparison");
    assert
      .dom(`${comparisonSelector} .inline-diff`)
      .doesNotExist("the previous mode is replaced");

    await click(".history-modal .side-by-side-mode");

    assert
      .dom(`${comparisonSelector} .revision-content`)
      .exists(
        { count: 2 },
        "switching back restores the side-by-side comparison"
      );
    assert
      .dom(`${comparisonSelector} table.markdown`)
      .doesNotExist("the markdown comparison is replaced");
    assert
      .dom(".revision__hidden-notice")
      .exists("switching modes preserves historical diff suppression");
    assert
      .dom("#revisions > .body-diff")
      .doesNotExist("switching modes never renders the hidden historical body");
  });

  test("removes the public comparison when navigating away from the last accessible revision", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article[data-post-id='419'] .edits button");
    await click(".history-modal .inline-mode");

    assert
      .dom(`${comparisonSelector} .inline-diff`)
      .exists("the last accessible revision offers the public comparison");

    await click(".history-modal .previous-revision");

    assert
      .dom(comparisonSelector)
      .doesNotExist(
        "an earlier revision does not retain the last revision's summary"
      );
    assert
      .dom(".revision__hidden-notice")
      .exists("the previous revision's historical diff remains suppressed");
    assert
      .dom("#revisions > .body-diff")
      .doesNotExist(
        "the previous revision does not expose a hidden historical body"
      );
    assert
      .dom("#revisions ins")
      .doesNotExist(
        "the current public comparison is not retained in the earlier edit"
      );

    await click(".history-modal .next-revision");

    assert
      .dom(`${comparisonSelector} ins`)
      .hasText(
        "was",
        "returning to the last revision restores the summary in the selected mode"
      );
    assert
      .dom(".revision__hidden-notice")
      .exists("returning to the summary preserves historical diff suppression");
  });

  test("shows the complexity notice when the public comparison exceeds the diff limit", async function (assert) {
    comparison = { from_version: 2, to_version: 5, diff_error: true };

    await visit("/t/internationalization-localization/280");
    await click("article[data-post-id='419'] .edits button");

    assert
      .dom(`${comparisonSelector} .alert-info`)
      .hasText(
        i18n("post.revisions.public_current_comparison", { from: 2, to: 5 }),
        "the oversized comparison still identifies its endpoints"
      );
    assert
      .dom(`${comparisonSelector} .alert-error`)
      .hasText(
        i18n("post.revisions.diff_too_complex"),
        "the existing complexity notice explains the missing comparison"
      );
    assert
      .dom(`${comparisonSelector} .body-diff`)
      .doesNotExist("an oversized comparison does not render an empty diff");
    assert
      .dom(".revision__hidden-notice")
      .exists(
        "the comparison error does not replace the historical-hidden notice"
      );
  });

  test("sanitizes rendered public comparison HTML", async function (assert) {
    comparison.body_changes.inline =
      '<div class="inline-diff"><p onclick="alert(1)">Public body</p><script>alert(1)</script></div>';

    await visit("/t/internationalization-localization/280");
    await click("article[data-post-id='419'] .edits button");
    await click(".history-modal .inline-mode");

    assert
      .dom(`${comparisonSelector} p[onclick]`)
      .doesNotExist("event handlers are stripped from public comparison HTML");
    assert
      .dom(`${comparisonSelector} script`)
      .doesNotExist("script elements are stripped from public comparison HTML");
    assert
      .dom(`${comparisonSelector} .inline-diff p`)
      .hasText("Public body", "safe public comparison content is preserved");
  });
});
