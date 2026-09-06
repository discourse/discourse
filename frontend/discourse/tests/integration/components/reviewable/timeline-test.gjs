import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import ReviewableTimeline from "discourse/components/reviewable/timeline";
import { CLAIMED, UNCLAIMED } from "discourse/models/reviewable-history";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Integration | Component | Reviewable | Timeline", function (hooks) {
  setupRenderingTest(hooks);

  function note(id, content) {
    return {
      id,
      content,
      created_at: `2024-01-0${id - 9}T00:00:00.000Z`,
      user: { id: 1, username: "moderator" },
    };
  }

  function storedReviewable(context, notes) {
    return getOwner(context)
      .lookup("service:store")
      .createRecord("reviewable", {
        id: 1,
        reviewable_scores: [],
        reviewable_notes: notes,
      });
  }

  function reviewableWithReason(reason) {
    return {
      reviewable_scores: [
        {
          created_at: "2024-01-01T00:00:00.000Z",
          user: { id: 1, username: "system" },
          score_type: { type: "needs_approval", title: "Needs Approval" },
          reason,
        },
      ],
    };
  }

  test("sanitizes dangerous markup in a flag reason but preserves safe links", async function (assert) {
    const reviewable = reviewableWithReason(
      `<p>Spam detected <img src=x onerror=alert(1)> <a href="javascript:alert(2)">phish</a> <a href="/admin">see settings</a></p>`
    );

    await render(
      <template><ReviewableTimeline @reviewable={{reviewable}} /></template>
    );

    assert
      .dom(".timeline-event__description")
      .hasHtml(
        '<p>Spam detected <img src=""> <a>phish</a> <a href="/admin">see settings</a></p>',
        "renders the sanitized flag reason"
      );
  });

  test("renders a cooked flag reason without altering its structure", async function (assert) {
    const reviewable = reviewableWithReason(
      "<p>First line<br>Second line</p><p>Fourth line</p>"
    );

    await render(
      <template><ReviewableTimeline @reviewable={{reviewable}} /></template>
    );

    assert
      .dom(".timeline-event__description")
      .hasHtml(
        "<p>First line<br>Second line</p><p>Fourth line</p>",
        "renders the cooked HTML directly"
      );
  });

  test("renders claimed and unclaimed history events", async function (assert) {
    const reviewable = { reviewable_scores: [] };
    const historyEvents = [
      {
        reviewable_history_type: CLAIMED,
        created_at: "2024-01-01T00:00:00.000Z",
        created_by: { id: 1, username: "moderator" },
      },
      {
        reviewable_history_type: UNCLAIMED,
        created_at: "2024-01-02T00:00:00.000Z",
        created_by: { id: 1, username: "moderator" },
      },
    ];

    await render(
      <template>
        <ReviewableTimeline
          @reviewable={{reviewable}}
          @historyEvents={{historyEvents}}
        />
      </template>
    );

    assert.dom(".timeline-event").exists({ count: 2 });
    assert.dom(".timeline-event__icon .d-icon-user-plus").exists();
    assert.dom(".timeline-event__icon .d-icon-user-xmark").exists();
  });

  test("renders the notes of the reviewable currently passed in", async function (assert) {
    const state = new (class {
      @tracked
      reviewable = {
        reviewable_scores: [],
        reviewable_notes: [note(10, "Note on the first reviewable")],
      };
    })();

    await render(
      <template>
        <ReviewableTimeline @reviewable={{state.reviewable}} />
      </template>
    );

    assert
      .dom(".timeline-event__description")
      .hasText("Note on the first reviewable", "renders the note it owns");

    state.reviewable = { reviewable_scores: [] };
    await settled();

    assert
      .dom(".timeline-event")
      .doesNotExist("drops the previous reviewable's notes");
  });

  test("renders a note pushed onto the reviewable after it was rendered", async function (assert) {
    const reviewable = storedReviewable(this, [note(10, "An existing note")]);

    await render(
      <template><ReviewableTimeline @reviewable={{reviewable}} /></template>
    );

    assert
      .dom(".timeline-event__description")
      .hasText("An existing note", "renders the note it was created with");

    reviewable.reviewable_notes.push(note(11, "A note added from the form"));
    await settled();

    assert
      .dom(".timeline-event:last-child .timeline-event__description")
      .hasText("A note added from the form", "appends the pushed note");
  });

  test("removes a deleted note from the timeline", async function (assert) {
    const reviewable = storedReviewable(this, [
      note(10, "A note that stays"),
      note(11, "A note that gets deleted"),
    ]);

    this.currentUser.admin = true;
    pretender.delete("/review/1/notes/11", () => response({}));

    await render(
      <template><ReviewableTimeline @reviewable={{reviewable}} /></template>
    );

    await click(".timeline-event:last-child .timeline-event__delete-note");

    assert
      .dom(".timeline-event")
      .exists({ count: 1 }, "drops the deleted note");
    assert.deepEqual(
      [...reviewable.reviewable_notes].map((n) => n.id),
      [10],
      "writes the removal back to the reviewable"
    );
  });
});
