import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { clipboardCopy } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import DFlashMessage from "discourse/ui-kit/d-flash-message";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class BlogReviews extends Component {
  @service dialog;
  @service toasts;

  @tracked busy = false;
  @tracked reviews = [];
  @tracked more = false;
  @tracked selectedReview;
  @tracked feedback = [];
  @tracked feedbackMore = false;

  #page = 0;
  #feedbackPage = 0;

  constructor() {
    super(...arguments);
    this.#load();
  }

  get baseUrl() {
    return `/blog/publications/${this.args.model.topicId}/reviews`;
  }

  formatDate(value) {
    return value ? new Date(value).toLocaleString() : "";
  }

  @action
  async create(data) {
    if (await this.#request(".json", { type: "POST", data })) {
      this.#page = 0;
      await this.#load();
    }
  }

  @action
  async copy(review) {
    try {
      await clipboardCopy(review.url);
      this.toasts.success({
        data: { message: i18n("blog.review.copied") },
      });
    } catch {
      this.dialog.alert({ message: i18n("blog.review.copy_failed") });
    }
  }

  @action
  revoke(review) {
    this.dialog.confirm({
      message: i18n("blog.review.revoke_confirm"),
      didConfirm: async () => {
        const result = await this.#request(`/${review.id}.json`, {
          type: "DELETE",
        });
        if (result !== false) {
          this.#page = 0;
          await this.#load();
        }
      },
    });
  }

  @action
  async loadMore() {
    await this.#load(this.#page + 1);
  }

  @action
  async viewFeedback(review) {
    const result = await this.#request(`/${review.id}/feedback.json`);
    if (result) {
      this.selectedReview = review;
      if (result.total !== undefined) {
        this.reviews = this.reviews.map((entry) =>
          entry.id === review.id
            ? { ...entry, feedback_count: result.total }
            : entry
        );
      }
      this.feedback = result.feedback;
      this.feedbackMore = result.more;
      this.#feedbackPage = 0;
    }
  }

  @action
  async loadMoreFeedback() {
    const page = this.#feedbackPage + 1;
    const result = await this.#request(
      `/${this.selectedReview.id}/feedback.json`,
      { data: { page } }
    );
    if (result) {
      this.feedback = [...this.feedback, ...result.feedback];
      this.feedbackMore = result.more;
      this.#feedbackPage = page;
    }
  }

  async #load(page = 0) {
    const result = await this.#request(".json", { data: { page } });
    if (result) {
      this.reviews = page
        ? [...this.reviews, ...result.reviews]
        : result.reviews;
      this.more = result.more;
      this.#page = page;
    }
  }

  async #request(path, options = {}) {
    this.busy = true;
    try {
      return await ajax(`${this.baseUrl}${path}`, options);
    } catch (error) {
      popupAjaxError(error);
      return false;
    } finally {
      if (!this.isDestroying) {
        this.busy = false;
      }
    }
  }

  <template>
    <DModal
      class="blog-reviews"
      @closeModal={{@closeModal}}
      @submitOnEnter={{false}}
      @title={{i18n "blog.review.manage"}}
    >
      <:body>
        {{#if @model.draft}}
          <DFlashMessage
            @flash={{i18n "blog.review.sharing_notice"}}
            @type="warning"
          />
          <Form
            class="blog-reviews__create"
            @onSubmit={{this.create}}
            as |form|
          >
            <form.Field
              @format="full"
              @name="label"
              @title={{i18n "blog.review.label"}}
              @type="input"
              as |field|
            ><field.Control maxlength="100" /></form.Field>
            <form.Actions><form.Submit
                @disabled={{this.busy}}
                @label="blog.review.create"
              /></form.Actions>
          </Form>
        {{/if}}
        <h3>{{i18n "blog.review.links"}}</h3>
        {{#if this.reviews}}
          <p class="blog-reviews__notice">{{i18n "blog.review.copy_notice"}}</p>
        {{/if}}
        {{#each this.reviews key="id" as |review|}}
          <section class="blog-reviews__entry" data-review-id={{review.id}}>
            <strong>{{review.label}}</strong>
            <p>{{i18n
                "blog.review.expires"
                date=(this.formatDate review.expires_at)
              }}</p>
            <p>{{i18n "blog.review.version" version=review.post_version}}
              ·
              {{#if review.active}}{{i18n "blog.review.active"}}{{else}}{{i18n
                  "blog.review.inactive"
                }}{{/if}}</p>
            {{#if review.url}}
              <div class="blog-reviews__link">
                <input
                  aria-label={{i18n "blog.review.link"}}
                  class="blog-reviews__link-url"
                  readonly
                  value={{review.url}}
                />
                <DButton
                  class="blog-reviews__copy"
                  @action={{fn this.copy review}}
                  @disabled={{this.busy}}
                  @icon="copy"
                  @label="blog.review.copy"
                />
                <a
                  class="blog-reviews__open"
                  href={{review.url}}
                  rel="noopener noreferrer"
                  target="_blank"
                >{{i18n "blog.review.open"}}</a>
              </div>
            {{/if}}
            <DButton
              class="blog-reviews__feedback-toggle"
              @action={{fn this.viewFeedback review}}
              @disabled={{this.busy}}
              @translatedLabel={{i18n
                "blog.review.feedback_count"
                count=review.feedback_count
              }}
            />
            {{#unless review.revoked_at}}
              <DButton
                class="blog-reviews__revoke"
                @action={{fn this.revoke review}}
                @disabled={{this.busy}}
                @label="blog.review.revoke"
              />
            {{/unless}}
          </section>
        {{else}}<p>{{i18n "blog.review.no_links"}}</p>{{/each}}
        {{#if this.more}}<DButton
            @action={{this.loadMore}}
            @disabled={{this.busy}}
            @label="blog.load_more"
          />{{/if}}
        {{#if this.selectedReview}}
          <h3>{{i18n
              "blog.review.feedback_for"
              version=this.selectedReview.post_version
            }}</h3>
          <p>{{i18n "blog.review.unverified"}}</p>
          {{#each this.feedback key="id" as |entry|}}
            <article class="blog-reviews__feedback">
              <strong>{{or entry.name (i18n "blog.review.anonymous")}}</strong>
              <span>{{entry.email}}</span>
              <time datetime={{entry.created_at}}>{{this.formatDate
                  entry.created_at
                }}</time>
              <p>{{entry.message}}</p>
            </article>
          {{else}}<p>{{i18n "blog.review.no_feedback"}}</p>{{/each}}
          {{#if this.feedbackMore}}<DButton
              @action={{this.loadMoreFeedback}}
              @disabled={{this.busy}}
              @label="blog.load_more"
            />{{/if}}
        {{/if}}
      </:body>
    </DModal>
  </template>
}
