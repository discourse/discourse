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
import { formatAiArtifactPostEmbed } from "discourse/plugins/discourse-ai/discourse/lib/ai-artifact-embed";

const SHARES_URL = "/discourse-ai/ai-bot/artifact-shares.json";

export default class SharedArtifactsList extends Component {
  @service dialog;
  @service toasts;

  @tracked items;
  @tracked hasMore;
  @tracked nextCursor;
  @tracked filter = "all";
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
    await this.#copy(this.#absoluteURL(item.url));
  }

  @action
  async copyPostEmbed(item) {
    if (this.loading || this._revokeConfirmationOpen || !item.available) {
      return;
    }
    await this.#copy(formatAiArtifactPostEmbed(item));
  }

  @action
  async copyWebsiteEmbed(item) {
    if (this.loading || this._revokeConfirmationOpen || !item.available) {
      return;
    }
    const url = this.#absoluteURL(item.embed_url || item.url);
    await this.#copy(
      `<iframe src="${url}" width="100%" height="600" frameborder="0"></iframe>`
    );
  }

  @action
  revoke(item) {
    if (this.loading || this._revokeConfirmationOpen) {
      return;
    }

    this._revokeConfirmationOpen = true;
    const isConversation = item.type === "conversation";
    return this.dialog.confirm({
      title: i18n(
        `discourse_ai.ai_artifact.confirm_revoke_${isConversation ? "conversation" : "standalone"}_title`
      ),
      message: i18n(
        `discourse_ai.ai_artifact.confirm_revoke_${isConversation ? "conversation" : "standalone"}_message`
      ),
      confirmButtonLabel: isConversation
        ? "discourse_ai.ai_artifact.revoke_conversation"
        : "discourse_ai.ai_artifact.revoke",
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
  async changeFilter(filter) {
    if (
      this.loading ||
      this._revokeConfirmationOpen ||
      filter === this.filter
    ) {
      return;
    }
    await this.#reload(filter, this.order);
  }

  @action
  async toggleSort() {
    if (this.loading || this._revokeConfirmationOpen) {
      return;
    }
    await this.#reload(
      this.filter,
      this.order === "newest" ? "oldest" : "newest"
    );
  }

  @action
  async loadMore() {
    if (this.loading || this._revokeConfirmationOpen || !this.canLoadMore) {
      return;
    }
    this.loading = true;
    try {
      const result = await this.#fetch(
        this.filter,
        this.order,
        this.nextCursor
      );
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
      const collection =
        item.type === "conversation"
          ? "shared-ai-conversations"
          : "artifact-shares";
      await ajax(`/discourse-ai/ai-bot/${collection}/${item.share_key}.json`, {
        type: "DELETE",
      });
      this.items = this.items.filter((entry) =>
        item.type === "conversation"
          ? entry.type !== "conversation" || entry.share_key !== item.share_key
          : entry.id !== item.id
      );
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  async #reload(filter, order) {
    this.loading = true;
    try {
      const result = await this.#fetch(filter, order);
      this.filter = filter;
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

  #fetch(filter, order, cursor) {
    return ajax(SHARES_URL, {
      data: {
        type: filter,
        order,
        ...(cursor !== null && cursor !== undefined
          ? { cursor: JSON.stringify(cursor) }
          : {}),
      },
    });
  }

  #absoluteURL(url) {
    if (/^(?:[a-z][a-z\d+.-]*:|\/\/)/i.test(url)) {
      return url;
    }
    return getAbsoluteURL(url.startsWith("/") ? url : `/${url}`);
  }

  #copy(text) {
    return clipboardCopy(text)
      .then(() =>
        this.toasts.success({
          duration: "short",
          data: { message: i18n("discourse_ai.ai_artifact.copied") },
        })
      )
      .catch((error) => popupAjaxError(error));
  }

  <template>
    <section
      aria-labelledby="shared-artifacts-heading"
      class="shared-artifacts"
      ...attributes
    >
      <h2 id="shared-artifacts-heading">{{i18n
          "discourse_ai.ai_artifact.shared_artifacts"
        }}</h2>
      <div class="shared-artifacts__controls">
        <div
          aria-label={{i18n "discourse_ai.ai_artifact.filter_shares"}}
          class="shared-artifacts__filters"
          role="group"
        >
          <DButton
            class="btn-flat"
            @action={{fn this.changeFilter "all"}}
            @ariaPressed={{eq this.filter "all"}}
            @disabled={{this.loading}}
            @label="discourse_ai.ai_artifact.filter_all"
          />
          <DButton
            class="btn-flat"
            @action={{fn this.changeFilter "standalone"}}
            @ariaPressed={{eq this.filter "standalone"}}
            @disabled={{this.loading}}
            @label="discourse_ai.ai_artifact.filter_standalone"
          />
          <DButton
            class="btn-flat"
            @action={{fn this.changeFilter "conversation"}}
            @ariaPressed={{eq this.filter "conversation"}}
            @disabled={{this.loading}}
            @label="discourse_ai.ai_artifact.filter_conversation"
          />
        </div>
        <DButton
          class="btn-flat shared-artifacts__sort"
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
        <ol class="shared-artifacts__list">
          {{#each this.items key="id" as |item|}}
            <li class="shared-artifacts__card">
              <div class="shared-artifacts__details">
                <h3>
                  {{#if item.available}}
                    <a
                      href={{item.url}}
                      rel="noopener noreferrer"
                      target="_blank"
                    >{{item.name}}</a>
                  {{else}}
                    {{item.name}}
                  {{/if}}
                </h3>
                <div class="shared-artifacts__meta">
                  <small>{{i18n
                      (if
                        (eq item.type "standalone")
                        "discourse_ai.ai_artifact.standalone"
                        "discourse_ai.ai_artifact.conversation"
                      )
                    }}</small>
                  {{#if item.created_at}}
                    <small>{{this.formattedDate item.created_at}}</small>
                  {{/if}}
                </div>
                {{#unless item.available}}
                  <p class="shared-artifacts__unavailable">{{i18n
                      "discourse_ai.ai_artifact.unavailable"
                    }}</p>
                {{/unless}}
              </div>
              <div class="shared-artifacts__actions">
                {{#if item.available}}
                  <DButton
                    class="btn-default shared-artifacts__copy-link"
                    @action={{fn this.copyLink item}}
                    @disabled={{this.loading}}
                    @icon="link"
                    @label="discourse_ai.ai_artifact.copy_link"
                  />
                  <DButton
                    class="btn-default shared-artifacts__embed-post"
                    @action={{fn this.copyPostEmbed item}}
                    @disabled={{this.loading}}
                    @icon="code"
                    @label="discourse_ai.ai_artifact.embed_post"
                    @title="discourse_ai.ai_artifact.embed_post_title"
                  />
                  <DButton
                    class="btn-default shared-artifacts__embed-website"
                    @action={{fn this.copyWebsiteEmbed item}}
                    @disabled={{this.loading}}
                    @icon="code"
                    @label="discourse_ai.ai_artifact.embed_website"
                    @title="discourse_ai.ai_artifact.embed_website_title"
                  />
                {{/if}}
                <DButton
                  class="btn-danger shared-artifacts__revoke"
                  @action={{fn this.revoke item}}
                  @disabled={{this.loading}}
                  @icon="far-trash-can"
                  @label={{if
                    (eq item.type "conversation")
                    "discourse_ai.ai_artifact.revoke_conversation"
                    "discourse_ai.ai_artifact.revoke"
                  }}
                />
              </div>
            </li>
          {{else}}
            {{#unless this.hasMore}}
              <li class="shared-artifacts__empty">{{i18n
                  "discourse_ai.ai_artifact.empty_shares"
                }}</li>
            {{/unless}}
          {{/each}}
        </ol>
      </DLoadMore>
      {{#if this.loading}}
        <div class="shared-artifacts__loading">{{dLoadingSpinner}}</div>
      {{/if}}
      {{#if this.loadError}}
        <DButton
          class="shared-artifacts__retry"
          @action={{this.retryLoad}}
          @disabled={{this.loading}}
          @label="discourse_ai.ai_artifact.retry_loading"
        />
      {{/if}}
    </section>
  </template>
}
