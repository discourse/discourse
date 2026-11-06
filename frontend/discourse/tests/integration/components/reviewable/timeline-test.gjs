import { tracked } from "@glimmer/tracking";
import { click, fillIn, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import ReviewableTimeline from "discourse/components/reviewable/timeline";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Integration | Component | Reviewable | Timeline", function (hooks) {
  setupRenderingTest(hooks);

  function note(id, content) {
    return {
      id,
      content,
      created_at: "2024-01-01T00:00:00.000Z",
      user: { id: 1, username: "moderator" },
    };
  }

  function storedReviewable(context, id, notes = []) {
    return context.owner.lookup("service:store").createRecord("reviewable", {
      id,
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
      `Spam detected <img src=x onerror=alert(1)> <a href="javascript:alert(2)">phish</a> <a href="/admin">see settings</a>`
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

  test("renders only the current reviewable's notes when navigating", async function (assert) {
    const first = storedReviewable(this, 1, [
      note(10, "First reviewable note"),
    ]);
    const empty = storedReviewable(this, 2);
    const second = storedReviewable(this, 3, [
      note(11, "Second reviewable note"),
    ]);
    const state = new (class {
      @tracked reviewable = first;
    })();

    await render(
      <template>
        <ReviewableTimeline @reviewable={{state.reviewable}} />
      </template>
    );

    assert
      .dom(".timeline-event__description")
      .hasText("First reviewable note", "shows the first reviewable's note");

    state.reviewable = empty;
    await settled();
    assert
      .dom(".timeline-event")
      .doesNotExist("does not carry notes to an empty reviewable");

    state.reviewable = second;
    await settled();
    assert
      .dom(".timeline-event__description")
      .hasText(
        "Second reviewable note",
        "shows the next reviewable's own note"
      );

    state.reviewable = first;
    await settled();
    assert
      .dom(".timeline-event__description")
      .hasText(
        "First reviewable note",
        "restores the original reviewable's note on return"
      );
  });

  test("adds a note to the current reviewable after navigating", async function (assert) {
    const first = storedReviewable(this, 1, [
      note(10, "First reviewable note"),
    ]);
    const second = storedReviewable(this, 2);
    const state = new (class {
      @tracked reviewable = first;
    })();
    pretender.post("/review/2/notes", () => response(note(11, "New note")));

    await render(
      <template>
        <ReviewableTimeline @reviewable={{state.reviewable}} />
      </template>
    );

    state.reviewable = second;
    await settled();
    await fillIn(".reviewable-note-form__textarea", "New note");
    await click(".reviewable-note-form button[type='submit']");

    assert
      .dom(".timeline-event")
      .exists({ count: 1 }, "only the new note appears");
    assert
      .dom(".timeline-event__description")
      .hasText("New note", "renders the created note immediately");
    assert.deepEqual(
      second.reviewable_notes.map((n) => n.id),
      [11],
      "stores the note on the current reviewable"
    );
    assert.deepEqual(
      first.reviewable_notes.map((n) => n.id),
      [10],
      "preserves the first reviewable's notes"
    );
  });

  test("keeps a deleted note removed when navigating away and back", async function (assert) {
    const first = storedReviewable(this, 1, [
      note(10, "Keep this note"),
      note(11, "Delete this note"),
    ]);
    const second = storedReviewable(this, 2);
    const state = new (class {
      @tracked reviewable = first;
    })();
    this.currentUser.admin = true;
    pretender.delete("/review/1/notes/11", () => response({}));

    await render(
      <template>
        <ReviewableTimeline @reviewable={{state.reviewable}} />
      </template>
    );
    await click(".timeline-event:last-child .timeline-event__delete-note");

    assert
      .dom(".timeline-event")
      .exists({ count: 1 }, "removes the deleted note immediately");
    assert.deepEqual(
      first.reviewable_notes.map((n) => n.id),
      [10],
      "writes the deletion back to the model"
    );

    state.reviewable = second;
    await settled();
    state.reviewable = first;
    await settled();

    assert
      .dom(".timeline-event")
      .exists({ count: 1 }, "does not restore the deleted note on return");
    assert
      .dom(".timeline-event__description")
      .hasText("Keep this note", "preserves the remaining note");
  });
});
