import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseLater from "discourse/lib/later";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import AiPayloadViewer from "discourse/plugins/discourse-ai/discourse/components/ai-payload-viewer";

export default class DebugAiModal extends Component {
  @tracked info = null;
  @tracked justCopiedText = "";
  @tracked activeTab = "request";

  constructor() {
    super(...arguments);
    next(() => {
      this.loadApiRequestInfo();
    });
  }

  get activePayload() {
    if (!this.info) {
      return null;
    }

    return this.activeTab === "request"
      ? this.info.raw_request_payload
      : this.info.raw_response_payload;
  }

  get activeCopyLabel() {
    return this.activeTab === "request"
      ? i18n("discourse_ai.ai_bot.debug_ai_modal.copy_request")
      : i18n("discourse_ai.ai_bot.debug_ai_modal.copy_response");
  }

  @action
  copied() {
    this.justCopiedText = i18n("discourse_ai.ai_bot.conversation_shared");

    discourseLater(() => {
      this.justCopiedText = "";
    }, 2000);
  }

  async loadLog(logId) {
    try {
      await ajax(`/discourse-ai/ai-bot/show-debug-info/${logId}.json`).then(
        (result) => {
          this.info = result;
        }
      );
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  prevLog() {
    this.loadLog(this.info.prev_log_id);
  }

  @action
  nextLog() {
    this.loadLog(this.info.next_log_id);
  }

  loadApiRequestInfo() {
    ajax(`/discourse-ai/ai-bot/post/${this.args.model.id}/show-debug-info.json`)
      .then((result) => {
        this.info = result;
      })
      .catch((e) => {
        popupAjaxError(e);
      });
  }

  get requestActive() {
    return this.activeTab === "request" ? "active" : "";
  }

  get responseActive() {
    return this.activeTab === "response" ? "active" : "";
  }

  @action
  requestClicked(e) {
    this.activeTab = "request";
    e.preventDefault();
  }

  @action
  responseClicked(e) {
    this.activeTab = "response";
    e.preventDefault();
  }

  get formattedDurationSummary() {
    const durationSeconds = this.seconds(this.info?.duration_msecs);
    const firstTokenSeconds = this.seconds(
      this.info?.time_to_first_token_msecs
    );

    if (durationSeconds == null) {
      return i18n("discourse_ai.ai_bot.debug_ai_modal.duration_unavailable");
    }

    if (firstTokenSeconds == null) {
      return i18n(
        "discourse_ai.ai_bot.debug_ai_modal.duration_without_first_token",
        { duration_seconds: durationSeconds }
      );
    }

    return i18n("discourse_ai.ai_bot.debug_ai_modal.duration", {
      duration_seconds: durationSeconds,
      first_token_seconds: firstTokenSeconds,
    });
  }

  seconds(milliseconds) {
    return milliseconds == null ? null : (milliseconds / 1000).toFixed(1);
  }

  get formattedSpending() {
    return this.formatCost(this.info?.spending);
  }

  get formattedConversationSpending() {
    return this.formatCost(this.info?.conversation_spending);
  }

  get turnCacheLabel() {
    return this.cacheLabel(
      this.info?.cache_read_tokens,
      this.info?.cache_write_tokens
    );
  }

  get conversationCacheLabel() {
    return this.cacheLabel(
      this.info?.conversation_cache_read_tokens,
      this.info?.conversation_cache_write_tokens
    );
  }

  get showConversationLine() {
    if (!this.info) {
      return false;
    }

    return (
      this.info.conversation_spending != null ||
      this.info.conversation_request_tokens > 0 ||
      this.info.conversation_response_tokens > 0 ||
      this.info.conversation_cache_read_tokens > 0 ||
      this.info.conversation_cache_write_tokens > 0
    );
  }

  cacheLabel(read, write) {
    const hasRead = read && read > 0;
    const hasWrite = write && write > 0;

    if (hasRead && hasWrite) {
      return i18n("discourse_ai.ai_bot.debug_ai_modal.cache_both", {
        read,
        write,
      });
    }
    if (hasRead) {
      return i18n("discourse_ai.ai_bot.debug_ai_modal.cache_read_only", {
        read,
      });
    }
    if (hasWrite) {
      return i18n("discourse_ai.ai_bot.debug_ai_modal.cache_write_only", {
        write,
      });
    }
    return null;
  }

  formatCost(value) {
    if (value == null || Number(value) === 0) {
      return null;
    }

    return `$${Number(value).toFixed(4)}`;
  }

  <template>
    <DModal
      class="ai-debug-modal"
      @title={{i18n "discourse_ai.ai_bot.debug_ai_modal.title"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <ul class="nav nav-pills ai-debug-modal__nav">
          <li><a
              href=""
              class={{this.requestActive}}
              {{on "click" this.requestClicked}}
            >{{i18n "discourse_ai.ai_bot.debug_ai_modal.request"}}</a></li>
          <li><a
              href=""
              class={{this.responseActive}}
              {{on "click" this.responseClicked}}
            >{{i18n "discourse_ai.ai_bot.debug_ai_modal.response"}}</a></li>
        </ul>
        {{#if this.info}}
          <div class="ai-debug-modal__stats">
            <p class="ai-debug-modal__stats-line">
              <strong class="ai-debug-modal__stats-line__label">
                {{i18n "discourse_ai.ai_bot.debug_ai_modal.this_turn"}}
              </strong>
              {{i18n
                "discourse_ai.ai_bot.debug_ai_modal.tokens_summary"
                request_tokens=this.info.request_tokens
                response_tokens=this.info.response_tokens
              }}
              {{#if this.turnCacheLabel}}
                <span
                  class="ai-debug-modal__stats-line__cache"
                >{{this.turnCacheLabel}}</span>
              {{/if}}
              {{#if this.formattedSpending}}
                <span class="ai-debug-modal__stats-line__cost">:
                  {{this.formattedSpending}}</span>
              {{/if}}
            </p>
            <p class="ai-debug-modal__stats-line ai-debug-modal__duration">
              <strong class="ai-debug-modal__stats-line__label">
                {{i18n "discourse_ai.ai_bot.debug_ai_modal.duration_label"}}
              </strong>
              {{this.formattedDurationSummary}}
            </p>
            {{#if this.showConversationLine}}
              <p class="ai-debug-modal__stats-line">
                <strong class="ai-debug-modal__stats-line__label">
                  {{i18n
                    "discourse_ai.ai_bot.debug_ai_modal.whole_conversation"
                  }}
                </strong>
                {{i18n
                  "discourse_ai.ai_bot.debug_ai_modal.tokens_summary"
                  request_tokens=this.info.conversation_request_tokens
                  response_tokens=this.info.conversation_response_tokens
                }}
                {{#if this.conversationCacheLabel}}
                  <span
                    class="ai-debug-modal__stats-line__cache"
                  >{{this.conversationCacheLabel}}</span>
                {{/if}}
                {{#if this.formattedConversationSpending}}
                  <span class="ai-debug-modal__stats-line__cost">:
                    {{this.formattedConversationSpending}}</span>
                {{/if}}
              </p>
            {{/if}}
          </div>
          <AiPayloadViewer
            class="ai-debug-modal__preview"
            @payload={{this.activePayload}}
            @copyLabel={{this.activeCopyLabel}}
            @onCopy={{this.copied}}
            @emptyMessage={{i18n
              "discourse_ai.ai_bot.debug_ai_modal.payload_unavailable"
            }}
          />
        {{/if}}
      </:body>

      <:footer>
        {{#if this.info.prev_log_id}}
          <DButton
            class="btn"
            @icon="angles-left"
            @action={{this.prevLog}}
            @label="discourse_ai.ai_bot.debug_ai_modal.previous_log"
          />
        {{/if}}
        {{#if this.info.next_log_id}}
          <DButton
            class="btn"
            @icon="angles-right"
            @action={{this.nextLog}}
            @label="discourse_ai.ai_bot.debug_ai_modal.next_log"
          />
        {{/if}}
        <span class="ai-debug-modal__just-copied">{{this.justCopiedText}}</span>
      </:footer>
    </DModal>
  </template>
}
