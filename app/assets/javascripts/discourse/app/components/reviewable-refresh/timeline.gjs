import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { and, eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import InterpolatedTranslation from "discourse/components/interpolated-translation";
import ReviewableFlagReason from "discourse/components/reviewable-refresh/flag-reason";
import ReviewableNoteForm from "discourse/components/reviewable-refresh/note-form";
import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

/**
 * Timeline component for reviewable items that displays chronological events
 * including flags, reviews, notes, and target post creation.
 *
 * @component ReviewableTimeline
 */
export default class ReviewableTimeline extends Component {
  @service currentUser;
  @service store;

  /**
   * The post being reviewed (if applicable)
   *
   * @type {Post}
   */
  @tracked reviewablePost;

  /**
   * Array of notes associated with the reviewable
   *
   * @type {Array<ReviewableNote>}
   */
  @tracked reviewableNotes = [];

  constructor() {
    super(...arguments);

    this.reviewableNotes = this.args.reviewable.reviewable_notes || [];

    // If we have a post_id but no post, we need to grab it from the store.
    if (this.args.reviewable.post_id && !this.reviewablePost) {
      this.store
        .find("post", this.args.reviewable.post_id)
        .then((post) => (this.reviewablePost = post));
    }
  }

  /**
   * Combines all timeline events from reviewable scores, histories, and the reviewable itself
   * and sorts them chronologically.
   *
   * @returns {Array<Object>} Array of timeline event objects sorted by date (newest first)
   */
  get timelineEvents() {
    const events = [];
    const reviewedEvents = new Map(); // Track reviewed events to prevent duplicates

    // Add target post creation event (when the original post was created)
    if (this.reviewablePost) {
      events.push({
        type: "target_created",
        date: this.reviewablePost.created_at,
        user: this.args.reviewable.target_created_by,
        icon: "clock",
        titleKey: "review.timeline.target_created_by",
      });
    }

    // Add flagging events from reviewable scores
    if (this.args.reviewable.reviewable_scores) {
      this.args.reviewable.reviewable_scores.forEach((score) => {
        // Build description for flagged event
        let flaggedDescription = "";
        if (score.reason || score.context) {
          flaggedDescription = `<p>${score.reason ?? ""}</p><p>${
            score.context ?? ""
          }</p>`;
        }

        // Add conversation message if available
        if (
          score.reviewable_conversation &&
          score.reviewable_conversation.conversation_posts &&
          score.reviewable_conversation.conversation_posts.length > 0
        ) {
          const firstPost = score.reviewable_conversation.conversation_posts[0];
          flaggedDescription += `<p>${firstPost.excerpt} (<a href="${
            score.reviewable_conversation.permalink
          }">${i18n("review.timeline.view_conversation")}</a>)</p>`;
        }

        events.push({
          type: "flagged",
          date: score.created_at,
          user: score.user,
          icon: "flag",
          titleKey: "review.timeline.flagged_as_by",
          description: htmlSafe(flaggedDescription),
          score: {
            count: 0,
            type: score.score_type.type,
            title: score.score_type.title,
          },
        });

        // Add separate reviewed event if both reviewed_by and reviewed_at are present
        if (score.reviewed_by && score.reviewed_at) {
          // Create a unique key for this reviewed event to prevent duplicates
          const reviewedKey = `${score.reviewed_by.id}-${score.reviewed_at}`;

          if (!reviewedEvents.has(reviewedKey)) {
            // Determine icon based on score status
            let reviewIcon;
            switch (score.status) {
              case 1: // approved
                reviewIcon = "check";
                break;
              case 2: // rejected
                reviewIcon = "times";
                break;
              case 3: // ignored
                reviewIcon = "far-eye-slash";
                break;
              default:
                reviewIcon = "check"; // fallback
            }

            const reviewedEvent = {
              type: "reviewed",
              date: score.reviewed_at,
              user: score.reviewed_by,
              icon: reviewIcon,
              titleKey: "review.timeline.reviewed_by",
              description: score.reason,
            };

            events.push(reviewedEvent);
            reviewedEvents.set(reviewedKey, reviewedEvent);
          }
        }
      });
    }

    // Add notes events
    this.reviewableNotes.forEach((note) => {
      const date = note.created_at;
      events.push({
        type: "note",
        date,
        user: note.user,
        icon: "far-pen-to-square",
        titleKey: "review.timeline.note_added_by",
        description: note.content,
        noteId: note.id,
        canDelete:
          this.currentUser &&
          note.user &&
          (this.currentUser.id === note.user.id || this.currentUser.admin),
      });
    });

    return events.sort((a, b) => Date.parse(b.date) - Date.parse(a.date));
  }

  /**
   * Handles creation of a new note.
   *
   * @param {Object} noteData - The created note data from the server
   */
  @action
  onNoteCreated(noteData) {
    // Ensure the note has a user object (fallback to current user if missing)
    if (!noteData.user && this.currentUser) {
      noteData.user = this.currentUser;
    }

    this.reviewableNotes = [...this.reviewableNotes, noteData];
  }

  /**
   * Handles deletion of a note.
   *
   * @param {number} noteId - ID of the note to delete
   */
  @action
  async deleteNote(noteId) {
    try {
      await ajax(`/reviewables/${this.args.reviewable.id}/notes/${noteId}`, {
        type: "DELETE",
      });

      // Remove the note from the local array
      this.reviewableNotes = this.reviewableNotes.filter(
        (note) => note.id !== noteId
      );
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <div class="reviewable-timeline">
      {{#if this.currentUser.staff}}
        <ReviewableNoteForm
          @reviewable={{this.args.reviewable}}
          @onNoteCreated={{this.onNoteCreated}}
        />
      {{/if}}

      {{#if this.timelineEvents}}
        <div class="timeline-events">
          {{#each this.timelineEvents as |event|}}
            <div class="timeline-event">
              <div class="timeline-event__icon">
                {{icon event.icon}}
              </div>

              <div class="timeline-event__content">
                <div class="timeline-event__main">
                  <div class="timeline-event__text">
                    <div class="timeline-event__title">
                      <InterpolatedTranslation
                        @key={{event.titleKey}}
                        as |Placeholder|
                      >
                        <Placeholder @name="flagReason">
                          <ReviewableFlagReason @score={{event.score}} />
                        </Placeholder>

                        <Placeholder @name="username">
                          {{avatar event.user imageSize="tiny"}}
                          <UserLink
                            @user={{event.user}}
                          >{{event.user.username}}</UserLink>
                        </Placeholder>

                        <Placeholder @name="relativeDate">
                          {{formatDate event.date format="medium"}}
                        </Placeholder>
                      </InterpolatedTranslation>
                    </div>
                    <div class="timeline-event__description">
                      {{event.description}}
                    </div>
                  </div>

                  {{#if (and (eq event.type "note") event.canDelete)}}
                    <div class="timeline-event__actions">
                      <DButton
                        @icon="trash-can"
                        @title="review.notes.delete_note"
                        @action={{fn this.deleteNote event.noteId}}
                        class="timeline-event__delete-note btn-transparent"
                      />
                    </div>
                  {{/if}}
                </div>

              </div>
            </div>
          {{/each}}
        </div>
      {{else}}
        <div class="timeline-empty">
          <div class="timeline-empty__icon">
            {{icon "clock"}}
          </div>
          <p class="timeline-empty__message">
            {{i18n "review.timeline.no_events"}}
          </p>
        </div>
      {{/if}}
    </div>
  </template>
}
