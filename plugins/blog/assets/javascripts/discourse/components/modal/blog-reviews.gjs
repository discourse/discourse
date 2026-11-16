import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { clipboardCopy } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

function shortDate(value) {
  const date = moment(value);
  return date.format(
    i18n(
      date.isSame(moment(), "year")
        ? "dates.long_no_year_no_time"
        : "dates.long_with_year_no_time"
    )
  );
}

function reviewStatus(review) {
  if (review.active) {
    return {
      key: "active",
      icon: "clock",
      modifier: "--success",
      detail: i18n("blog.review.expires", {
        date: shortDate(review.expires_at),
      }),
    };
  }
  if (review.revoked_by_publish) {
    return {
      key: "published",
      detail: i18n("blog.review.closed_on", {
        date: shortDate(review.revoked_at),
      }),
    };
  }
  if (review.revoked_at) {
    return {
      key: "revoked",
      detail: i18n("blog.review.revoked_on", {
        date: shortDate(review.revoked_at),
      }),
    };
  }
  if (new Date(review.expires_at) <= new Date()) {
    return {
      key: "expired",
      detail: i18n("blog.review.expired_on", {
        date: shortDate(review.expires_at),
      }),
    };
  }
  return { key: "inactive" };
}

export default class BlogReviews extends Component {
  @service dialog;
  @service toasts;

  @tracked busy = false;
  @tracked reviews = [];
  @tracked more = false;

  #form;
  #page = 0;

  constructor() {
    super(...arguments);
    this.#load();
  }

  get baseUrl() {
    return `/blog-editor/publications/${this.args.model.topicId}/reviews`;
  }

  @action
  registerForm(api) {
    this.#form = api;
  }

  @action
  async create(data) {
    if (await this.#request(".json", { type: "POST", data })) {
      this.#form?.reset();
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
      this.dialog.alert({
        message: i18n("blog.review.copy_failed", { url: review.url }),
      });
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
  showFeedback() {
    this.args.closeModal({ showFeedback: true });
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
          <section class="blog-reviews__new">
            <p class="blog-reviews__intro">{{i18n "blog.review.intro"}}</p>
            <Form
              class="blog-reviews__create"
              @commitOnSubmit={{false}}
              @onRegisterApi={{this.registerForm}}
              @onSubmit={{this.create}}
              as |form|
            >
              <form.Field
                class="blog-reviews__label-field"
                @format="full"
                @name="label"
                @title={{i18n "blog.review.label"}}
                @type="input"
                as |field|
              ><field.Control
                  maxlength="100"
                  placeholder={{i18n "blog.review.label_placeholder"}}
                /></form.Field>
              <form.Submit
                @disabled={{this.busy}}
                @label="blog.review.create"
              />
            </Form>
          </section>
        {{/if}}

        {{#if this.reviews}}
          <section class="blog-reviews__list">
            <h3 class="blog-reviews__heading">{{i18n "blog.review.links"}}</h3>

            {{#each this.reviews key="id" as |review|}}
              {{#let (reviewStatus review) as |status|}}
                <article
                  class={{dConcatClass
                    "blog-reviews__entry"
                    (unless review.active "--inactive")
                  }}
                  data-review-id={{review.id}}
                >
                  <header class="blog-reviews__entry-header">
                    <div class="blog-reviews__entry-summary">
                      <div class="blog-reviews__entry-heading">
                        <h4 class="blog-reviews__entry-title">{{if
                            review.label
                            review.label
                            (i18n "blog.review.untitled")
                          }}</h4>
                        <span
                          class={{dConcatClass
                            "blog-reviews__status"
                            status.modifier
                          }}
                        >{{i18n
                            (concat "blog.review.status." status.key)
                          }}</span>
                      </div>
                      <p class="blog-reviews__entry-meta">
                        {{#if status.detail}}
                          <span class="blog-reviews__detail">
                            {{#if status.icon}}{{dIcon status.icon}}{{/if}}
                            {{status.detail}}
                          </span>
                        {{/if}}
                        {{#if review.feedback_count}}
                          <DButton
                            class="btn-link blog-reviews__feedback-link"
                            @action={{this.showFeedback}}
                            @translatedLabel={{i18n
                              "blog.review.feedback_count"
                              count=review.feedback_count
                            }}
                          />
                        {{else}}
                          <span class="blog-reviews__no-feedback">{{i18n
                              "blog.review.no_feedback"
                            }}</span>
                        {{/if}}
                      </p>
                    </div>
                    {{#unless review.revoked_at}}
                      <div class="blog-reviews__entry-buttons">
                        {{#if review.url}}
                          <DButton
                            class="btn-default btn-small blog-reviews__copy"
                            @action={{fn this.copy review}}
                            @disabled={{this.busy}}
                            @icon="copy"
                            @label="blog.review.copy"
                          />
                          <a
                            class="btn btn-default btn-small blog-reviews__open"
                            href={{review.url}}
                            rel="noopener noreferrer"
                            target="_blank"
                          >{{dIcon "up-right-from-square"}}<span
                              class="d-button-label"
                            >{{i18n "blog.review.open"}}</span></a>
                        {{/if}}
                        <DButton
                          class="btn-default btn-small blog-reviews__revoke"
                          @action={{fn this.revoke review}}
                          @disabled={{this.busy}}
                          @icon="ban"
                          @label="blog.review.revoke"
                        />
                      </div>
                    {{/unless}}
                  </header>

                </article>
              {{/let}}
            {{/each}}

            {{#if this.more}}
              <DButton
                class="btn-default blog-reviews__load-more"
                @action={{this.loadMore}}
                @disabled={{this.busy}}
                @label="blog.load_more"
              />
            {{/if}}
          </section>
        {{else}}
          {{#unless @model.draft}}
            <p class="blog-reviews__empty">{{i18n "blog.review.no_links"}}</p>
          {{/unless}}
        {{/if}}
      </:body>
    </DModal>
  </template>
}
