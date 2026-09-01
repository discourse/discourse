import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";
import { eq, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DCopyButton from "discourse/ui-kit/d-copy-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import AiDecodedTranscript from "discourse/plugins/discourse-ai/discourse/components/ai-decoded-transcript";
import AiPayloadViewer from "discourse/plugins/discourse-ai/discourse/components/ai-payload-viewer";
import {
  decodedResponseText,
  isDecodedResponse,
} from "discourse/plugins/discourse-ai/discourse/lib/decoded-response";

export default class AiLogDetailModal extends Component {
  @tracked log;
  @tracked loading = true;
  @tracked failed = false;
  @tracked notFound = false;
  @tracked activeTab = "request";
  @tracked showRawResponse = false;

  constructor() {
    super(...arguments);
    next(() => this.load());
  }

  get tabs() {
    const tabs = [
      { id: "request", label: i18n("discourse_ai.logs.detail.request") },
      { id: "response", label: i18n("discourse_ai.logs.detail.response") },
    ];

    if (this.log?.feature_context) {
      tabs.push({
        id: "context",
        label: i18n("discourse_ai.logs.detail.context"),
      });
    }
    if (this.log?.request_attempts?.length) {
      tabs.push({
        id: "attempts",
        label: i18n("discourse_ai.logs.detail.attempts"),
      });
    }
    return tabs;
  }

  get activePayload() {
    return this.activeTab === "request"
      ? this.log?.raw_request_payload
      : this.log?.raw_response_payload;
  }

  get activePayloadTruncated() {
    return this.activeTab === "request"
      ? this.log?.raw_request_payload_truncated
      : this.log?.raw_response_payload_truncated;
  }

  get hasDecodedResponse() {
    return isDecodedResponse(this.log?.decoded_response);
  }

  get showDecodedResponse() {
    return (
      this.activeTab === "response" &&
      !this.showRawResponse &&
      this.hasDecodedResponse
    );
  }

  get showResponseToggle() {
    return this.activeTab === "response" && this.hasDecodedResponse;
  }

  get copyPayload() {
    if (this.activeTab === "context") {
      return this.contextPayload;
    }

    if (this.showDecodedResponse) {
      return decodedResponseText(this.log.decoded_response);
    }

    if (this.activeTab === "request" || this.activeTab === "response") {
      return this.activePayload;
    }

    return null;
  }

  get activeCopyLabel() {
    if (this.activeTab === "context") {
      return i18n("discourse_ai.logs.detail.copy_context");
    }

    if (this.activeTab === "request") {
      return i18n("discourse_ai.logs.detail.copy_request");
    }

    if (!this.hasDecodedResponse) {
      return i18n("discourse_ai.logs.detail.copy_response");
    }

    return i18n(
      `discourse_ai.logs.detail.${
        this.showRawResponse ? "copy_raw_response" : "copy_response"
      }`
    );
  }

  get responseToggleLabel() {
    return i18n(
      `discourse_ai.${this.showRawResponse ? "view_decoded" : "view_raw"}`
    );
  }

  get contextPayload() {
    return this.log?.feature_context
      ? JSON.stringify(this.log.feature_context)
      : null;
  }

  get formattedOutcome() {
    const successful =
      (this.log?.response_status >= 200 && this.log?.response_status <= 299) ||
      (this.log?.response_status == null &&
        Number(this.log?.response_tokens || 0) > 0);
    const outcome = i18n(
      `discourse_ai.logs.${successful ? "successful" : "failed"}`
    );

    return this.log?.response_status == null
      ? outcome
      : i18n("discourse_ai.logs.detail.outcome_with_status", {
          outcome,
          status: this.log.response_status,
        });
  }

  get formattedCreatedAt() {
    return this.log?.created_at
      ? moment(this.log.created_at).format("LLL")
      : "—";
  }

  get formattedDuration() {
    return this.log?.duration_msecs == null
      ? "—"
      : i18n("discourse_ai.logs.detail.duration_seconds", {
          seconds: this.seconds(this.log.duration_msecs),
        });
  }

  get formattedFirstToken() {
    return i18n("discourse_ai.logs.detail.duration_seconds", {
      seconds: this.seconds(this.log.time_to_first_token_msecs),
    });
  }

  get hasFirstToken() {
    return this.log?.time_to_first_token_msecs != null;
  }

  get hasCost() {
    return Number(this.log?.spending) > 0;
  }

  get formattedCost() {
    return this.log?.spending == null
      ? "—"
      : `$${Number(this.log.spending).toFixed(4)}`;
  }

  get topicUrl() {
    return this.log?.topic_id ? getURL(`/t/${this.log.topic_id}`) : null;
  }

  get postUrl() {
    return this.log?.post_id ? getURL(`/p/${this.log.post_id}`) : null;
  }

  @action
  async load() {
    this.loading = true;
    this.failed = false;
    this.notFound = false;
    this.showRawResponse = false;

    try {
      const log = await ajax(
        `/admin/plugins/discourse-ai/ai-logs/${this.args.model.logId}.json`
      );
      if (!this.isDestroying && !this.isDestroyed) {
        this.log = log;
      }
    } catch (error) {
      if (!this.isDestroying && !this.isDestroyed) {
        this.failed = true;
        this.notFound = error.jqXHR?.status === 404;
      }
    } finally {
      if (!this.isDestroying && !this.isDestroyed) {
        this.loading = false;
      }
    }
  }

  seconds(milliseconds) {
    return (milliseconds / 1000).toFixed(1);
  }

  @action
  attemptStatus(attempt) {
    return attempt.status === 0
      ? i18n("discourse_ai.logs.detail.network_error")
      : attempt.status;
  }

  @action
  selectTab(tab) {
    this.activeTab = tab;
    this.showRawResponse = false;
  }

  @action
  toggleResponseView() {
    this.showRawResponse = !this.showRawResponse;
  }

  @action
  close() {
    this.args.model.onClose?.();
    this.args.closeModal();
  }

  <template>
    <DModal
      class="ai-log-detail-modal"
      @title={{i18n "discourse_ai.logs.detail.title" id=@model.logId}}
      @closeModal={{this.close}}
    >
      <:body>
        {{#if this.loading}}
          <DConditionalLoadingSpinner @condition={{true}} />
        {{else if this.failed}}
          <div class="ai-log-detail-modal__error">
            <p>{{if
                this.notFound
                (i18n "discourse_ai.logs.detail.load_error")
                (i18n "discourse_ai.logs.detail.generic_load_error")
              }}</p>
            <DButton
              class="btn-default"
              @action={{this.load}}
              @label="discourse_ai.logs.retry"
            />
          </div>
        {{else}}
          <dl class="ai-log-detail-modal__metadata">
            <div><dt>{{i18n "discourse_ai.logs.time"}}</dt><dd
              >{{this.formattedCreatedAt}}</dd></div>
            <div><dt>{{i18n "discourse_ai.logs.outcome"}}</dt><dd
              >{{this.formattedOutcome}}</dd></div>
            <div><dt>{{i18n "discourse_ai.logs.feature"}}</dt><dd>{{or
                  this.log.feature_name
                  "—"
                }}</dd></div>
            <div><dt>{{i18n "discourse_ai.logs.model"}}</dt><dd>{{or
                  this.log.model_name
                  this.log.language_model
                  "—"
                }}</dd></div>
            <div><dt>{{i18n "discourse_ai.logs.provider"}}</dt><dd>{{or
                  this.log.provider_name
                  "—"
                }}</dd></div>
            <div class="ai-log-detail-modal__metadata-duration"><dt>{{i18n
                  "discourse_ai.logs.duration"
                }}</dt><dd>{{this.formattedDuration}}</dd></div>
            {{#if this.hasFirstToken}}
              <div class="ai-log-detail-modal__metadata-first-token"><dt>{{i18n
                    "discourse_ai.logs.first_token"
                  }}</dt><dd>{{this.formattedFirstToken}}</dd></div>
            {{/if}}
            {{#if this.hasCost}}
              <div class="ai-log-detail-modal__metadata-cost"><dt>{{i18n
                    "discourse_ai.logs.cost"
                  }}</dt><dd>{{this.formattedCost}}</dd></div>
            {{/if}}
            <div><dt>{{i18n "discourse_ai.logs.tokens"}}</dt><dd
              >{{this.log.request_tokens}}
                →
                {{this.log.response_tokens}}</dd></div>
            <div><dt>{{i18n "discourse_ai.logs.cache_read_tokens"}}</dt><dd>{{or
                  this.log.cache_read_tokens
                  0
                }}</dd></div>
            <div><dt>{{i18n "discourse_ai.logs.cache_write_tokens"}}</dt><dd
              >{{or this.log.cache_write_tokens 0}}</dd></div>
            {{#if this.log.username}}
              <div><dt>{{i18n "discourse_ai.logs.user"}}</dt><dd
                >{{this.log.username}}</dd></div>
            {{/if}}
            {{#if this.topicUrl}}
              <div><dt>{{i18n "discourse_ai.logs.topic"}}</dt><dd><a
                    href={{this.topicUrl}}
                  >{{this.log.topic_id}}</a></dd></div>
            {{/if}}
            {{#if this.postUrl}}
              <div><dt>{{i18n "discourse_ai.logs.post"}}</dt><dd><a
                    href={{this.postUrl}}
                  >{{this.log.post_id}}</a></dd></div>
            {{/if}}
          </dl>

          <div class="ai-log-detail-modal__tabs">
            <nav
              class="ai-log-detail-modal__tab-list"
              aria-label={{i18n "discourse_ai.logs.detail.tabs_label"}}
            >
              {{#each this.tabs as |tab|}}
                <DButton
                  class={{if
                    (eq this.activeTab tab.id)
                    "btn-primary"
                    "btn-default"
                  }}
                  @action={{fn this.selectTab tab.id}}
                  @ariaPressed={{eq this.activeTab tab.id}}
                  @translatedLabel={{tab.label}}
                />
              {{/each}}
            </nav>
            {{#if this.copyPayload}}
              <div class="ai-log-detail-modal__actions">
                {{#if this.showResponseToggle}}
                  <DButton
                    class="btn-default ai-log-detail-modal__response-toggle"
                    @action={{this.toggleResponseView}}
                    @translatedLabel={{this.responseToggleLabel}}
                  />
                {{/if}}
                <DCopyButton
                  @value={{this.copyPayload}}
                  @copyClass="btn-default ai-log-detail-modal__copy"
                  @translatedLabel={{this.activeCopyLabel}}
                  @translatedLabelAfterCopy={{i18n "discourse_ai.copied"}}
                />
              </div>
            {{/if}}
          </div>

          {{#if this.showDecodedResponse}}
            <AiDecodedTranscript
              class="ai-log-detail-modal__preview"
              @response={{this.log.decoded_response}}
            />
          {{else if
            (or (eq this.activeTab "request") (eq this.activeTab "response"))
          }}
            <AiPayloadViewer
              @payload={{this.activePayload}}
              @unbounded={{true}}
              @truncated={{this.activePayloadTruncated}}
              @emptyMessage={{i18n
                "discourse_ai.logs.detail.payload_unavailable"
              }}
              @truncatedMessage={{i18n
                "discourse_ai.logs.detail.payload_truncated"
              }}
            />
          {{else if (eq this.activeTab "context")}}
            <AiPayloadViewer
              @payload={{this.contextPayload}}
              @unbounded={{true}}
              @emptyMessage={{i18n
                "discourse_ai.logs.detail.payload_unavailable"
              }}
            />
          {{else}}
            <ol class="ai-log-detail-modal__attempts">
              {{#each this.log.request_attempts as |attempt|}}
                <li>
                  {{i18n
                    "discourse_ai.logs.detail.attempt"
                    status=(this.attemptStatus attempt)
                    delay=attempt.delay_ms
                  }}
                </li>
              {{/each}}
            </ol>
          {{/if}}
        {{/if}}
      </:body>
    </DModal>
  </template>
}
