import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, uniqueId } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import Form from "discourse/components/form";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import EmbedMode from "discourse/lib/embed-mode";
import { longDate } from "discourse/lib/formatter";
import DiscourseURL from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";
import DComboButton from "discourse/ui-kit/d-combo-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DFlashMessage from "discourse/ui-kit/d-flash-message";
import DInterpolatedTranslation from "discourse/ui-kit/d-interpolated-translation";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import { i18n } from "discourse-i18n";
import BlogReviews from "./modal/blog-reviews.gjs";
import BlogSchedule from "./modal/blog-schedule.gjs";

export default class BlogPublicationPanel extends Component {
  @service appEvents;
  @service dialog;
  @service modal;
  @service toasts;

  @tracked busy = false;
  @tracked diff;
  @tracked diffOpen = false;
  @tracked feedback;
  @tracked feedbackMore = false;
  @tracked feedbackOpen = false;
  @tracked settingsOpen = false;
  // The settings form keeps its own snapshot so state changes do not discard edits in progress.
  @tracked settingsData;
  #feedbackPage = 0;
  #form;
  #menu;
  #replaced;
  @tracked _publication;

  constructor() {
    super(...arguments);
    this.appEvents.on("composer:edited-post", this, this.refresh);
    this.settingsData = this.#settingsSnapshot();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off("composer:edited-post", this, this.refresh);
  }

  get publication() {
    // A topic reload replaces the serialized entry, which supersedes any locally applied mutation.
    const override = this._publication;
    const base = this.args.outletArgs.model.blog_publication;
    return base && base === this.#replaced ? override : base;
  }

  get visible() {
    return !!this.publication && !EmbedMode.enabled;
  }

  get isDiscussion() {
    return this.publication.role === "discussion";
  }

  get status() {
    return this.publication.status;
  }

  get statusClass() {
    return `--${this.status.replaceAll("_", "-")}`;
  }

  get badge() {
    return i18n(`blog.panel.badge.${this.status}`);
  }

  get headline() {
    if (this.status === "scheduled") {
      return i18n("blog.panel.headline.scheduled", {
        date: longDate(new Date(this.publication.scheduled_at)),
      });
    }
    return i18n(`blog.panel.headline.${this.status}`);
  }

  get displayUrl() {
    return this.publication.url.replace(/^https?:\/\//, "");
  }

  get publishedDate() {
    return longDate(
      new Date(
        this.publication.last_published_at || this.publication.published_at
      )
    );
  }

  get changedFields() {
    return this.publication.changes
      .map((field) => i18n(`blog.panel.change.${field}`))
      .join(", ");
  }

  get hasPendingChanges() {
    return this.publication.published && this.publication.changes.length > 0;
  }

  get canShowDiff() {
    return (
      this.hasPendingChanges &&
      this.publication.changes.some((field) =>
        ["title", "body"].includes(field)
      )
    );
  }

  get pendingRevision() {
    const submitted = this.publication.submitted_revision;
    if (!submitted || submitted.id === this.publication.published_revision_id) {
      return null;
    }
    return submitted;
  }

  get hasReviews() {
    return (
      this.publication.review_feedback_count > 0 ||
      this.publication.active_review_links > 0
    );
  }

  get canRelease() {
    return !this.publication.published || this.hasPendingChanges;
  }

  get primaryLabel() {
    if (!this.publication.can_publish) {
      return "blog.panel.submit";
    }
    return this.hasPendingChanges
      ? "blog.panel.publish_correction"
      : "blog.panel.publish";
  }

  @action
  registerForm(api) {
    this.#form = api;
  }

  @action
  registerMenu(api) {
    this.#menu = api;
  }

  @action
  toggleSettings() {
    this.settingsOpen = !this.settingsOpen;
  }

  @action
  async toggleDiff() {
    if (!this.diffOpen && !this.diff) {
      this.busy = true;
      try {
        this.diff = await ajax(this.#url("/changes"));
      } catch (error) {
        popupAjaxError(error);
        return;
      } finally {
        this.busy = false;
      }
    }
    this.diffOpen = !this.diffOpen;
  }

  @action
  async toggleFeedback() {
    if (!this.feedbackOpen && !this.feedback) {
      if (!(await this.#loadFeedback(0))) {
        return;
      }
    }
    this.feedbackOpen = !this.feedbackOpen;
  }

  @action
  loadMoreFeedback() {
    return this.#loadFeedback(this.#feedbackPage + 1);
  }

  @action
  async refresh() {
    if (!this.publication) {
      return;
    }
    try {
      this.#apply(await ajax(this.#url("")));
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async publish() {
    await this.#menu?.close();
    const correction = this.hasPendingChanges;
    this.dialog.confirm({
      message: i18n(
        correction
          ? "blog.panel.publish_correction_confirm"
          : "blog.panel.publish_confirm",
        { title: this.publication.title }
      ),
      didConfirm: async () => {
        if (await this.#mutate("/publish")) {
          this.#announcePublished();
        }
      },
    });
  }

  @action
  async publishRevision(revision) {
    if (this.publication.approved_revision?.id !== revision.id) {
      if (!(await this.#mutate("/approve", { revision_id: revision.id }))) {
        return;
      }
    }
    if (await this.#mutate("/publish", { revision_id: revision.id })) {
      this.#announcePublished();
    }
  }

  @action
  async submit() {
    await this.#menu?.close();
    await this.#mutate("/submit");
  }

  @action
  async openSchedule() {
    await this.#menu?.close();
    this.modal.show(BlogSchedule, { model: { onSchedule: this.schedule } });
  }

  @action
  async schedule(scheduledAt) {
    // Scheduling freezes the draft as it is now, so it goes through submission and approval first.
    const submitted = await this.#mutate("/submit");
    if (!submitted) {
      return false;
    }
    const revisionId = submitted.submitted_revision.id;
    if (!(await this.#mutate("/approve", { revision_id: revisionId }))) {
      return false;
    }
    return this.#mutate("/schedule", {
      revision_id: revisionId,
      scheduled_at: new Date(scheduledAt).toISOString(),
    });
  }

  @action
  cancelSchedule() {
    return this.#mutate("/schedule", {}, "DELETE");
  }

  @action
  async unpublish() {
    await this.#menu?.close();
    this.dialog.confirm({
      message: i18n("blog.unpublish_confirm"),
      didConfirm: () => this.#mutate("", {}, "DELETE"),
    });
  }

  @action
  async saveSettings(data) {
    const current = this.publication.published_at;
    const result = await this.#mutate(
      "",
      {
        publication: {
          ...data,
          published_at:
            data.published_at === current?.slice(0, 10)
              ? current
              : data.published_at || null,
        },
      },
      "PUT"
    );
    if (result) {
      this.#form.commit();
    }
  }

  @action
  shareForReview() {
    const open = async () => {
      await this.modal.show(BlogReviews, {
        model: { topicId: this.publication.source_topic_id, draft: true },
      });
      // Links may have been issued or revoked while the modal was open.
      await this.refresh();
    };
    if (this.#form?.isDirty) {
      this.dialog.confirm({
        message: i18n("blog.review.discard_metadata"),
        didConfirm: open,
      });
    } else {
      open();
    }
  }

  @action
  async editPrivately() {
    let url = this.publication.source_url;
    if (!url) {
      const result = await this.#mutate("/prepare");
      if (!result) {
        return;
      }
      url = result.source_url;
    }
    DiscourseURL.routeTo(url);
  }

  #url(suffix) {
    return `/blog/publications/${this.publication.id}${suffix}.json`;
  }

  async #loadFeedback(page) {
    this.busy = true;
    try {
      const result = await ajax(
        `/blog/publications/${this.publication.source_topic_id}/feedback.json`,
        { data: { page } }
      );
      this.feedback = page
        ? [...this.feedback, ...result.feedback]
        : result.feedback;
      this.feedbackMore = result.more;
      this.#feedbackPage = page;
      return true;
    } catch (error) {
      popupAjaxError(error);
      return false;
    } finally {
      this.busy = false;
    }
  }

  async #mutate(suffix, data = {}, type = "POST") {
    this.busy = true;
    try {
      const entry =
        (await ajax(this.#url(suffix), { type, data })) ||
        (await ajax(this.#url("")));
      this.#apply(entry);
      return entry;
    } catch (error) {
      popupAjaxError(error);
      return false;
    } finally {
      this.busy = false;
    }
  }

  #apply(entry) {
    // The editor endpoints do not know which topic is being viewed, so the role is kept.
    const { role } = this.publication;
    this.#replaced = this.args.outletArgs.model.blog_publication;
    this._publication = { ...entry, role };
    this.diff = null;
    this.diffOpen = false;
    this.feedback = null;
    this.feedbackOpen = false;
    if (!this.#form?.isDirty) {
      this.settingsData = this.#settingsSnapshot();
    }
  }

  #settingsSnapshot() {
    return {
      path: this.publication?.path,
      excerpt: this.publication?.excerpt || "",
      featured: this.publication?.featured,
      published_at: this.publication?.published_at?.slice(0, 10) || "",
    };
  }

  #announcePublished() {
    this.toasts.success({
      data: {
        message: i18n("blog.panel.published", {
          id: this.publication.published_revision_id,
        }),
      },
    });
  }

  <template>
    {{#if this.visible}}
      {{#if this.isDiscussion}}
        <div class="blog-discussion-banner">
          <span
            class="blog-discussion-banner__badge
              {{if this.publication.live '--live' '--unpublished'}}"
          >{{i18n
              (if
                this.publication.live
                "blog.panel.discussion.live"
                "blog.panel.discussion.not_live"
              )
            }}</span>
          <p class="blog-discussion-banner__text">
            {{#if this.publication.live}}
              <DInterpolatedTranslation
                @key="blog.panel.discussion.intro"
                as |Placeholder|
              >
                <Placeholder @name="article">
                  <a
                    href={{this.publication.url}}
                    rel="noopener noreferrer"
                    target="_blank"
                  >{{this.displayUrl}} ↗</a>
                </Placeholder>
              </DInterpolatedTranslation>
            {{else}}
              {{i18n "blog.panel.discussion.intro_not_live"}}
            {{/if}}
            {{#if this.publication.source_url}}
              <DInterpolatedTranslation
                @key={{if
                  this.publication.draft_correction
                  "blog.panel.discussion.working_copy_pending"
                  "blog.panel.discussion.working_copy"
                }}
                as |Placeholder|
              >
                <Placeholder @name="link">
                  <a href={{this.publication.source_url}}>{{i18n
                      "blog.panel.discussion.working_copy_link"
                    }}</a>
                </Placeholder>
              </DInterpolatedTranslation>
            {{else}}
              {{i18n "blog.panel.discussion.no_working_copy"}}
            {{/if}}
          </p>
          <DButton
            class="btn-default blog-discussion-banner__edit"
            @action={{this.editPrivately}}
            @disabled={{this.busy}}
            @label="blog.panel.discussion.edit_privately"
          />
        </div>
      {{else}}
        {{#let (uniqueId) as |settingsId|}}
          <section
            aria-label={{i18n "blog.panel.aria_label"}}
            class="blog-publication-panel {{this.statusClass}}"
          >
            <div class="blog-publication-panel__summary">
              <div class="blog-publication-panel__status">
                <span
                  class="blog-publication-panel__badge {{this.statusClass}}"
                >{{this.badge}}</span>
                <span
                  class="blog-publication-panel__headline"
                >{{this.headline}}</span>
              </div>
              <p class="blog-publication-panel__meta">
                {{#if (eq this.status "draft")}}
                  <DInterpolatedTranslation
                    @key="blog.panel.will_publish_to"
                    as |Placeholder|
                  >
                    <Placeholder @name="url">
                      <a
                        href={{this.publication.url}}
                        rel="noopener noreferrer"
                        target="_blank"
                      >{{this.displayUrl}}</a>
                    </Placeholder>
                  </DInterpolatedTranslation>
                  {{#if this.publication.draft_updated_at}}
                    <span
                      aria-hidden="true"
                      class="blog-publication-panel__sep"
                    >·</span>
                    <DInterpolatedTranslation
                      @key="blog.panel.saved"
                      as |Placeholder|
                    >
                      <Placeholder @name="age">{{dAgeWithTooltip
                          this.publication.draft_updated_at
                        }}</Placeholder>
                    </DInterpolatedTranslation>
                  {{/if}}
                {{else if (eq this.status "scheduled")}}
                  {{i18n
                    "blog.panel.scheduled_revision"
                    id=this.publication.scheduled_revision.id
                    user=this.publication.scheduled_revision.approved_by
                  }}
                  <span
                    aria-hidden="true"
                    class="blog-publication-panel__sep"
                  >·</span>
                  {{i18n "blog.panel.scheduled_notice"}}
                {{else if (eq this.status "unpublished")}}
                  {{i18n "blog.panel.last_published" date=this.publishedDate}}
                  <span
                    aria-hidden="true"
                    class="blog-publication-panel__sep"
                  >·</span>
                  {{i18n "blog.panel.unpublished_notice"}}
                {{else}}
                  {{i18n
                    "blog.panel.published_as"
                    date=this.publishedDate
                    id=this.publication.published_revision_id
                  }}
                  <span
                    aria-hidden="true"
                    class="blog-publication-panel__sep"
                  >·</span>
                  <a
                    class="blog-publication-panel__view-live"
                    href={{this.publication.url}}
                    rel="noopener noreferrer"
                    target="_blank"
                  >{{i18n "blog.panel.view_live"}}</a>
                  {{#if this.publication.edits_since_publish}}
                    <span
                      aria-hidden="true"
                      class="blog-publication-panel__sep"
                    >·</span>
                    {{i18n
                      "blog.panel.edits_since"
                      count=this.publication.edits_since_publish
                    }}
                  {{/if}}
                {{/if}}
              </p>
            </div>

            <div class="blog-publication-panel__actions">
              {{#if (eq this.status "scheduled")}}
                <a
                  class="btn btn-default blog-publication-panel__preview"
                  href={{this.publication.scheduled_revision.preview_url}}
                  rel="noopener noreferrer"
                  target="_blank"
                >{{i18n
                    "blog.panel.preview_revision"
                    id=this.publication.scheduled_revision.id
                  }}</a>
                {{#if this.publication.can_publish}}
                  <DButton
                    class="btn-default blog-publication-panel__cancel-schedule"
                    @action={{this.cancelSchedule}}
                    @disabled={{this.busy}}
                    @label="blog.panel.cancel_schedule"
                  />
                  <DButton
                    class="btn-primary blog-publication-panel__publish-now"
                    @action={{fn
                      this.publishRevision
                      this.publication.scheduled_revision
                    }}
                    @disabled={{this.busy}}
                    @label="blog.panel.publish_now"
                  />
                {{/if}}
              {{else}}
                <a
                  class="btn btn-default blog-publication-panel__preview"
                  href={{this.publication.preview_url}}
                  rel="noopener noreferrer"
                  target="_blank"
                >{{i18n "blog.panel.preview"}}</a>
                {{#if this.publication.source_topic_id}}
                  <DButton
                    class="btn-default blog-publication-panel__reviews"
                    @action={{this.shareForReview}}
                    @disabled={{this.busy}}
                    @label="blog.panel.share_for_review"
                  />
                {{/if}}
                {{#if this.canRelease}}
                  <DComboButton
                    class="blog-publication-panel__primary"
                    @btnTypeClass="btn-primary"
                    @hasMenu={{this.publication.can_publish}}
                    as |combo|
                  >
                    <combo.Button
                      class="blog-publication-panel__publish"
                      @action={{if
                        this.publication.can_publish
                        this.publish
                        this.submit
                      }}
                      @disabled={{this.busy}}
                      @label={{this.primaryLabel}}
                    />
                    <combo.Menu
                      class="blog-publication-panel__menu-trigger"
                      @identifier="blog-publish-menu"
                      @modalForMobile={{true}}
                      @onRegisterApi={{this.registerMenu}}
                      @title={{i18n "blog.panel.more_options"}}
                    >
                      <DDropdownMenu as |dropdown|>
                        <dropdown.item>
                          <DButton
                            class="btn-transparent --with-description blog-publication-panel__menu-item blog-publication-panel__menu-publish"
                            @action={{this.publish}}
                          >
                            <span
                              class="blog-publication-panel__menu-label"
                            >{{i18n "blog.panel.publish_now"}}</span>
                            <span
                              class="blog-publication-panel__menu-hint"
                            >{{i18n
                                (if
                                  this.hasPendingChanges
                                  "blog.panel.publish_correction_hint"
                                  "blog.panel.publish_now_hint"
                                )
                              }}</span>
                          </DButton>
                        </dropdown.item>
                        <dropdown.item>
                          <DButton
                            class="btn-transparent --with-description blog-publication-panel__menu-item blog-publication-panel__menu-schedule"
                            @action={{this.openSchedule}}
                          >
                            <span
                              class="blog-publication-panel__menu-label"
                            >{{i18n "blog.panel.schedule"}}</span>
                            <span
                              class="blog-publication-panel__menu-hint"
                            >{{i18n "blog.panel.schedule_hint"}}</span>
                          </DButton>
                        </dropdown.item>
                        <dropdown.item>
                          <DButton
                            class="btn-transparent --with-description blog-publication-panel__menu-item blog-publication-panel__menu-submit"
                            @action={{this.submit}}
                          >
                            <span
                              class="blog-publication-panel__menu-label"
                            >{{i18n "blog.panel.submit"}}</span>
                            <span
                              class="blog-publication-panel__menu-hint"
                            >{{i18n "blog.panel.submit_hint"}}</span>
                          </DButton>
                        </dropdown.item>
                        {{#if this.publication.published}}
                          <dropdown.divider />
                          <dropdown.item>
                            <DButton
                              class="btn-transparent --with-description blog-publication-panel__menu-item blog-publication-panel__unpublish"
                              @action={{this.unpublish}}
                            >
                              <span
                                class="blog-publication-panel__menu-label"
                              >{{i18n "blog.unpublish"}}</span>
                              <span
                                class="blog-publication-panel__menu-hint"
                              >{{i18n "blog.panel.unpublish_hint"}}</span>
                            </DButton>
                          </dropdown.item>
                        {{/if}}
                      </DDropdownMenu>
                    </combo.Menu>
                  </DComboButton>
                {{else if this.publication.can_publish}}
                  {{! Nothing differs from the live article, so only withdrawal is offered. }}
                  <DMenu
                    class="btn-default blog-publication-panel__options"
                    @disabled={{this.busy}}
                    @icon="chevron-down"
                    @identifier="blog-publish-menu"
                    @label={{i18n "blog.panel.options"}}
                    @modalForMobile={{true}}
                    @onRegisterApi={{this.registerMenu}}
                  >
                    <:content>
                      <DDropdownMenu as |dropdown|>
                        <dropdown.item>
                          <DButton
                            class="btn-transparent --with-description blog-publication-panel__menu-item blog-publication-panel__unpublish"
                            @action={{this.unpublish}}
                          >
                            <span
                              class="blog-publication-panel__menu-label"
                            >{{i18n "blog.unpublish"}}</span>
                            <span
                              class="blog-publication-panel__menu-hint"
                            >{{i18n "blog.panel.unpublish_hint"}}</span>
                          </DButton>
                        </dropdown.item>
                      </DDropdownMenu>
                    </:content>
                  </DMenu>
                {{/if}}
              {{/if}}
            </div>

            {{#if this.pendingRevision}}
              <div class="blog-publication-panel__pending">
                <span>{{i18n
                    "blog.panel.submitted"
                    id=this.pendingRevision.id
                  }}</span>
                <a
                  href={{this.pendingRevision.preview_url}}
                  rel="noopener noreferrer"
                  target="_blank"
                >{{i18n
                    "blog.panel.preview_revision"
                    id=this.pendingRevision.id
                  }}</a>
                {{#if this.publication.can_publish}}
                  <DButton
                    class="btn-default blog-publication-panel__approve"
                    @action={{fn this.publishRevision this.pendingRevision}}
                    @disabled={{this.busy}}
                    @translatedLabel={{i18n
                      "blog.panel.approve_and_publish"
                      id=this.pendingRevision.id
                    }}
                  />
                {{/if}}
              </div>
            {{/if}}

            {{#if this.hasPendingChanges}}
              <div class="blog-publication-panel__changes">
                <div class="blog-publication-panel__changes-header">
                  <span class="blog-publication-panel__changes-title">{{i18n
                      "blog.panel.changes_title"
                    }}</span>
                  {{#if this.canShowDiff}}
                    <DButton
                      aria-expanded={{if this.diffOpen "true" "false"}}
                      class="btn-flat blog-publication-panel__toggle-diff"
                      @action={{this.toggleDiff}}
                      @disabled={{this.busy}}
                      @label={{if
                        this.diffOpen
                        "blog.panel.hide_diff"
                        "blog.panel.show_diff"
                      }}
                    />
                  {{/if}}
                </div>
                <p class="blog-publication-panel__changed">{{i18n
                    "blog.panel.changed"
                    fields=this.changedFields
                  }}</p>
                {{#if this.diffOpen}}
                  {{#if this.diff.diff_error}}
                    <p class="blog-publication-panel__diff-error">{{i18n
                        "blog.panel.diff_error"
                      }}</p>
                  {{else}}
                    {{#if this.diff.title_diff_html}}
                      <div class="blog-publication-panel__diff --title">
                        {{trustHTML this.diff.title_diff_html}}
                      </div>
                    {{/if}}
                    <div class="blog-publication-panel__diff">
                      {{trustHTML this.diff.diff_html}}
                    </div>
                  {{/if}}
                {{/if}}
              </div>
            {{/if}}

            {{#if this.hasReviews}}
              <div class="blog-publication-panel__reviews">
                <div class="blog-publication-panel__reviews-header">
                  <span class="blog-publication-panel__reviews-title">
                    {{#if this.publication.review_feedback_count}}
                      {{i18n
                        "blog.panel.feedback.count"
                        count=this.publication.review_feedback_count
                      }}
                    {{else}}
                      {{i18n "blog.panel.feedback.none"}}
                    {{/if}}
                    <span
                      aria-hidden="true"
                      class="blog-publication-panel__sep"
                    >·</span>
                    <span class="blog-publication-panel__reviews-links">{{#if
                        this.publication.active_review_links
                      }}{{i18n
                          "blog.panel.feedback.active_links"
                          count=this.publication.active_review_links
                        }}{{else}}{{i18n
                          "blog.panel.feedback.no_active_links"
                        }}{{/if}}</span>
                  </span>
                  <span class="blog-publication-panel__reviews-actions">
                    {{#if this.publication.review_feedback_count}}
                      <DButton
                        aria-expanded={{if this.feedbackOpen "true" "false"}}
                        class="btn-flat blog-publication-panel__toggle-feedback"
                        @action={{this.toggleFeedback}}
                        @disabled={{this.busy}}
                        @label={{if
                          this.feedbackOpen
                          "blog.panel.feedback.hide"
                          "blog.panel.feedback.show"
                        }}
                      />
                    {{/if}}
                    <DButton
                      class="btn-flat blog-publication-panel__manage-reviews"
                      @action={{this.shareForReview}}
                      @disabled={{this.busy}}
                      @label="blog.panel.feedback.manage_links"
                    />
                  </span>
                </div>
                {{#if this.feedbackOpen}}
                  <p class="blog-publication-panel__feedback-notice">{{i18n
                      "blog.review.unverified"
                    }}</p>
                  <ul class="blog-publication-panel__feedback">
                    {{#each this.feedback key="id" as |entry|}}
                      <li class="blog-publication-panel__feedback-entry">
                        <div class="blog-publication-panel__feedback-meta">
                          <strong>{{or
                              entry.name
                              (i18n "blog.review.anonymous")
                            }}</strong>
                          {{#if entry.email}}
                            <span
                              class="blog-publication-panel__feedback-email"
                            >{{entry.email}}</span>
                          {{/if}}
                          <span
                            aria-hidden="true"
                            class="blog-publication-panel__sep"
                          >·</span>
                          {{dAgeWithTooltip entry.created_at}}
                          <span
                            aria-hidden="true"
                            class="blog-publication-panel__sep"
                          >·</span>
                          <span
                            class="blog-publication-panel__feedback-review"
                          >{{#if entry.review.label}}{{entry.review.label}}
                              <span
                                aria-hidden="true"
                                class="blog-publication-panel__sep"
                              >·</span>{{/if}}{{i18n
                              "blog.review.version"
                              version=entry.review.post_version
                            }}</span>
                        </div>
                        <p
                          class="blog-publication-panel__feedback-message"
                        >{{entry.message}}</p>
                      </li>
                    {{/each}}
                  </ul>
                  {{#if this.feedbackMore}}
                    <DButton
                      class="btn-flat blog-publication-panel__more-feedback"
                      @action={{this.loadMoreFeedback}}
                      @disabled={{this.busy}}
                      @label="blog.load_more"
                    />
                  {{/if}}
                {{/if}}
              </div>
            {{/if}}

            {{#if this.publication.schedule_error}}
              <div class="blog-publication-panel__error">
                <DFlashMessage
                  @flash={{this.publication.schedule_error}}
                  @type="error"
                />
              </div>
            {{/if}}

            <div class="blog-publication-panel__settings">
              <DButton
                aria-controls={{settingsId}}
                aria-expanded={{if this.settingsOpen "true" "false"}}
                class="btn-flat blog-publication-panel__settings-toggle"
                @action={{this.toggleSettings}}
                @icon={{if this.settingsOpen "chevron-down" "chevron-right"}}
                @label="blog.panel.settings"
              >
                <span class="blog-publication-panel__settings-hint">{{i18n
                    "blog.panel.settings_hint"
                  }}</span>
              </DButton>
              <div hidden={{unless this.settingsOpen true}} id={{settingsId}}>
                <Form
                  class="blog-publication-panel__form"
                  @data={{this.settingsData}}
                  @onRegisterApi={{this.registerForm}}
                  @onSubmit={{this.saveSettings}}
                  as |form|
                >
                  <form.Field
                    @description={{i18n "blog.path_hint"}}
                    @format="full"
                    @name="path"
                    @title={{i18n "blog.path"}}
                    @type="input"
                    @validation="required"
                    as |field|
                  ><field.Control maxlength="240" /></form.Field>
                  <form.Field
                    @description={{i18n "blog.excerpt_hint"}}
                    @format="full"
                    @name="excerpt"
                    @title={{i18n "blog.excerpt"}}
                    @type="textarea"
                    as |field|
                  ><field.Control maxlength="1000" @rows={{3}} /></form.Field>
                  <form.Field
                    @description={{i18n "blog.date_hint"}}
                    @name="published_at"
                    @title={{i18n "blog.date"}}
                    @type="input"
                    as |field|
                  ><field.Control @type="date" /></form.Field>
                  <form.Field
                    @name="featured"
                    @title={{i18n "blog.featured"}}
                    @type="checkbox"
                    as |field|
                  ><field.Control /></form.Field>
                  <form.Actions>
                    <form.Submit @disabled={{this.busy}} @label="blog.save" />
                  </form.Actions>
                </Form>
              </div>
            </div>
          </section>
        {{/let}}
      {{/if}}
    {{/if}}
  </template>
}
