import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { shortDate } from "discourse/lib/formatter";
import { getAbsoluteURL } from "discourse/lib/get-url";
import { clipboardCopy } from "discourse/lib/utilities";
import { eq, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DLoadMore from "discourse/ui-kit/d-load-more";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";
import { i18n } from "discourse-i18n";

const SHARES_URL = "/discourse-ai/ai-bot/shared-ai-conversations.json";

export default class SharedConversationsList extends Component {
  @service dialog;
  @service toasts;

  @tracked items;
  @tracked hasMore;
  @tracked nextCursor;
  @tracked order = "newest";
  @tracked loading = false;
  @tracked loadError = false;
  @tracked _revokeConfirmationOpen = false;

  constructor() {
    super(...arguments);
    this.items = this.args.data.items;
    this.hasMore = this.args.data.has_more;
    this.nextCursor = this.args.data.next_cursor;
  }

  get canLoadMore() {
    return this.hasMore && !this.loadError && !this._revokeConfirmationOpen;
  }

  formattedDate(date) {
    return shortDate(new Date(date));
  }

  @action
  async copyLink(item) {
    if (this.loading || this._revokeConfirmationOpen || !item.available) {
      return;
    }
    const url = /^(?:[a-z][a-z\d+.-]*:|\/\/)/i.test(item.url)
      ? item.url
      : getAbsoluteURL(item.url.startsWith("/") ? item.url : `/${item.url}`);
    try {
      await clipboardCopy(url);
      this.toasts.success({
        duration: "short",
        data: { message: i18n("discourse_ai.ai_artifact.copied") },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  revoke(item) {
    if (this.loading || this._revokeConfirmationOpen) {
      return;
    }

    this._revokeConfirmationOpen = true;
    return this.dialog.confirm({
      title: i18n("discourse_ai.ai_artifact.confirm_revoke_conversation_title"),
      message: i18n(
        "discourse_ai.ai_artifact.confirm_revoke_conversation_message"
      ),
      confirmButtonLabel: "discourse_ai.ai_artifact.revoke_conversation",
      confirmButtonClass: "btn-danger",
      didConfirm: () => {
        this._revokeConfirmationOpen = false;
        this.#revokeConfirmed(item);
      },
      didCancel: () => {
        this._revokeConfirmationOpen = false;
      },
    });
  }

  @action
  async toggleSort() {
    if (this.loading || this._revokeConfirmationOpen) {
      return;
    }
    this.loading = true;
    try {
      const order = this.order === "newest" ? "oldest" : "newest";
      const result = await this.#fetch(order);
      this.order = order;
      this.items = result.items;
      this.hasMore = result.has_more;
      this.nextCursor = result.next_cursor;
      this.loadError = false;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  async loadMore() {
    if (this.loading || this._revokeConfirmationOpen || !this.canLoadMore) {
      return;
    }
    this.loading = true;
    try {
      const result = await this.#fetch(this.order, this.nextCursor);
      this.items = [...this.items, ...result.items];
      this.hasMore = result.has_more;
      this.nextCursor = result.next_cursor;
      this.loadError = false;
    } catch {
      this.loadError = true;
    } finally {
      this.loading = false;
    }
  }

  @action
  retryLoad() {
    if (this.loading || this._revokeConfirmationOpen || !this.loadError) {
      return;
    }
    this.loadError = false;
    return this.loadMore();
  }

  async #revokeConfirmed(item) {
    if (this.loading) {
      return;
    }
    this.loading = true;
    try {
      await ajax(
        `/discourse-ai/ai-bot/shared-ai-conversations/${item.share_key}.json`,
        { type: "DELETE" }
      );
      this.items = this.items.filter((entry) => entry.id !== item.id);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  #fetch(order, cursor) {
    return ajax(SHARES_URL, {
      data: {
        order,
        ...(cursor !== null && cursor !== undefined
          ? { cursor: JSON.stringify(cursor) }
          : {}),
      },
    });
  }

  <template>
    <section
      aria-labelledby="shared-conversations-heading"
      class="shared-conversations"
      ...attributes
    >
      <h2 id="shared-conversations-heading">{{i18n
          "discourse_ai.shared_ai_conversations.title"
        }}</h2>
      <div class="shared-conversations__controls">
        <DButton
          class="btn-flat shared-conversations__sort"
          @action={{this.toggleSort}}
          @disabled={{this.loading}}
          @icon="chevron-down"
          @label={{if
            (eq this.order "oldest")
            "discourse_ai.ai_artifact.oldest_first"
            "discourse_ai.ai_artifact.newest_first"
          }}
        />
      </div>
      <DLoadMore
        @action={{this.loadMore}}
        @enabled={{this.canLoadMore}}
        @isLoading={{or this.loading this.loadError}}
      >
        <ol class="shared-conversations__list">
          {{#each this.items key="id" as |item|}}
            <li class="shared-conversations__card">
              <div class="shared-conversations__details">
                <h3>
                  {{#if item.available}}
                    <a
                      href={{item.url}}
                      rel="noopener noreferrer"
                      target="_blank"
                    >{{item.title}}</a>
                  {{else}}
                    {{item.title}}
                  {{/if}}
                </h3>
                {{#if item.created_at}}
                  <div class="shared-conversations__meta">
                    <small>{{this.formattedDate item.created_at}}</small>
                  </div>
                {{/if}}
                {{#unless item.available}}
                  <p class="shared-conversations__unavailable">{{i18n
                      "discourse_ai.shared_ai_conversations.unavailable"
                    }}</p>
                {{/unless}}
              </div>
              <div class="shared-conversations__actions">
                {{#if item.available}}
                  <DButton
                    class="btn-default shared-conversations__copy-link"
                    @action={{fn this.copyLink item}}
                    @disabled={{this.loading}}
                    @icon="link"
                    @label="discourse_ai.ai_artifact.copy_link"
                  />
                {{/if}}
                <DButton
                  class="btn-danger shared-conversations__revoke"
                  @action={{fn this.revoke item}}
                  @disabled={{this.loading}}
                  @icon="far-trash-can"
                  @label="discourse_ai.ai_artifact.revoke_conversation"
                />
              </div>
            </li>
          {{else}}
            {{#unless this.hasMore}}
              <li class="shared-conversations__empty">{{i18n
                  "discourse_ai.shared_ai_conversations.empty"
                }}</li>
            {{/unless}}
          {{/each}}
        </ol>
      </DLoadMore>
      {{#if this.loading}}
        <div class="shared-conversations__loading">{{dLoadingSpinner}}</div>
      {{/if}}
      {{#if this.loadError}}
        <DButton
          class="shared-conversations__retry"
          @action={{this.retryLoad}}
          @disabled={{this.loading}}
          @label="discourse_ai.ai_artifact.retry_loading"
        />
      {{/if}}
    </section>
  </template>
}
