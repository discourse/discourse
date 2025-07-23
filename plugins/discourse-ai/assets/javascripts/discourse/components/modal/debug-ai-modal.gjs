import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
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

    return htmlSafe(safe);
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
        <div class="ai-debug-modal__tokens">
          <span class="ai-debug-modal__tokens__count">
            {{i18n "discourse_ai.ai_bot.debug_ai_modal.request_tokens"}}
            {{this.info.request_tokens}}
          </span>
          <span class="ai-debug-modal__tokens__count">
            {{i18n "discourse_ai.ai_bot.debug_ai_modal.response_tokens"}}
            {{this.info.response_tokens}}
          </span>
        </div>
        <div class="debug-ai-modal__preview">
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
        <span class="ai-debut-modal__just-copied">{{this.justCopiedText}}</span>
      </:footer>
    </DModal>
  </template>
}
