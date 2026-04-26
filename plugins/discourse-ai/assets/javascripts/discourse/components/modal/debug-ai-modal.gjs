import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { trustHTML } from "@ember/template";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseLater from "discourse/lib/later";
import { clipboardCopy, escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import { jsonToHtml } from "../../lib/utilities";

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

  get htmlContext() {
    if (!this.info) {
      return "";
    }

    let parsed;

    try {
      if (this.activeTab === "request") {
        parsed = JSON.parse(this.info.raw_request_payload);
      } else {
        return this.formattedResponse(this.info.raw_response_payload);
      }
    } catch {
      return this.info.raw_request_payload;
    }

    return jsonToHtml(parsed);
  }

  formattedResponse(response) {
    // we need to replace the new lines with <br> to make it look good
    const split = response.split("\n");
    const safe = split.map((line) => escapeExpression(line)).join("<br>");

    return trustHTML(safe);
  }

  @action
  copyRequest() {
    this.copy(this.info.raw_request_payload);
  }

  @action
  copyResponse() {
    this.copy(this.info.raw_response_payload);
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

  copy(text) {
    clipboardCopy(text);
    this.justCopiedText = i18n("discourse_ai.ai_bot.conversation_shared");

    discourseLater(() => {
      this.justCopiedText = "";
    }, 2000);
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
          {{#if this.showConversationLine}}
            <p class="ai-debug-modal__stats-line">
              <strong class="ai-debug-modal__stats-line__label">
                {{i18n "discourse_ai.ai_bot.debug_ai_modal.whole_conversation"}}
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
        <div class="ai-debug-modal__preview">
          {{this.htmlContext}}
        </div>
      </:body>

      <:footer>
        <DButton
          class="btn confirm"
          @icon="copy"
          @action={{this.copyRequest}}
          @label="discourse_ai.ai_bot.debug_ai_modal.copy_request"
        />
        <DButton
          class="btn confirm"
          @icon="copy"
          @action={{this.copyResponse}}
          @label="discourse_ai.ai_bot.debug_ai_modal.copy_response"
        />
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
