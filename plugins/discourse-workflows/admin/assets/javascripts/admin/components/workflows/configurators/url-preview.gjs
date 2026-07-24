import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { isTesting } from "discourse/lib/environment";
import { getAbsoluteURL } from "discourse/lib/get-url";
import { clipboardCopy } from "discourse/lib/utilities";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ExpressionWrapper from "./expression-wrapper";

export default class UrlPreview extends Component {
  @tracked copied = false;
  @tracked mode = "production";
  @tracked testUrl = null;
  @tracked isStartingTestSession = false;
  @tracked now = Date.now();
  countdownTimer = null;

  willDestroy() {
    super.willDestroy(...arguments);
    this.stopCountdown();
  }

  get isFormTrigger() {
    return this.args.node?.type === "trigger:form";
  }

  get isWebhookTrigger() {
    return this.args.node?.type === "trigger:webhook";
  }

  get isTestableTrigger() {
    return this.isFormTrigger || this.isWebhookTrigger;
  }

  get isTestMode() {
    return this.isTestableTrigger && this.mode === "test";
  }

  get displayPath() {
    const value = this.args.configuration?.path || "";

    if (typeof value === "string" && value.startsWith("=")) {
      return "<expression>";
    }

    return value || "<path>";
  }

  get productionUrl() {
    const webhookId = this.args.node?.webhookId;
    if (this.isFormTrigger && webhookId) {
      return getAbsoluteURL(`/workflows/form/${webhookId}`);
    }

    return getAbsoluteURL(`/workflows/webhooks/${this.displayPath}`);
  }

  get webhookTestListener() {
    if (!this.isWebhookTrigger) {
      return null;
    }

    return this.args.session?.webhookTestListenerForNode(
      this.args.node.clientId
    );
  }

  get activeTestUrl() {
    if (this.isWebhookTrigger) {
      return this.webhookTestListener?.testUrl;
    }

    return this.testUrl;
  }

  get previewUrl() {
    if (this.isTestMode && this.activeTestUrl) {
      return getAbsoluteURL(this.activeTestUrl);
    }

    return this.productionUrl;
  }

  get previewText() {
    if (this.isTestMode && !this.activeTestUrl) {
      return i18n("discourse_workflows.form.listen_for_test_event");
    }

    return this.previewUrl;
  }

  get previewIcon() {
    if (this.isTestMode && !this.activeTestUrl) {
      return this.isStartingTestSession ? "spinner" : "arrow-pointer";
    }

    return this.copied ? "check" : "copy";
  }

  get previewTitle() {
    if (this.isTestMode && !this.activeTestUrl) {
      return i18n("discourse_workflows.form.listen_for_test_event");
    }

    return i18n("discourse_workflows.webhook.click_to_copy");
  }

  get hint() {
    if (this.isFormTrigger) {
      return i18n("discourse_workflows.form.save_for_url");
    }

    return null;
  }

  get hasUrl() {
    if (this.isFormTrigger) {
      return !!this.args.node?.webhookId;
    }

    return true;
  }

  get canStartTestSession() {
    return this.isTestableTrigger && this.args.session?.workflowId;
  }

  get isTestSessionUnavailable() {
    return this.isTestMode && !this.canStartTestSession;
  }

  @action
  setMode(mode) {
    this.mode = mode;
    if (mode === "test" && this.webhookTestListener) {
      this.startCountdown();
    }
  }

  @action
  async startTestSession() {
    if (!this.canStartTestSession || this.isStartingTestSession) {
      return;
    }

    this.isStartingTestSession = true;
    try {
      await this.args.onBeforeStartTestSession?.();

      if (this.isWebhookTrigger) {
        await this.args.session.startWebhookTestListener(
          this.args.node.clientId
        );
        this.startCountdown();
      } else {
        const result = await ajax(
          `/admin/plugins/discourse-workflows/workflows/${this.args.session.workflowId}/form-test-sessions.json`,
          {
            type: "POST",
            data: { trigger_node_id: this.args.node.clientId },
          }
        );
        this.testUrl = result.test_url;
        window.open(getAbsoluteURL(this.testUrl), "_blank");
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isStartingTestSession = false;
    }
  }

  @action
  async cancelTestSession(event) {
    event?.stopPropagation();
    if (!this.isWebhookTrigger || !this.webhookTestListener) {
      return;
    }

    try {
      await this.args.session.cancelWebhookTestListener(
        this.args.node.clientId
      );
      this.stopCountdown();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async copy() {
    await clipboardCopy(this.previewUrl);
    this.copied = true;
    setTimeout(() => (this.copied = false), 2000);
  }

  @action
  async previewAction() {
    if (this.isTestMode && !this.activeTestUrl) {
      await this.startTestSession();
      return;
    }

    await this.copy();
  }

  get expiresInSeconds() {
    const expiresAt = this.webhookTestListener?.expiresAt;
    if (!expiresAt) {
      return null;
    }

    return Math.max(0, Math.ceil((Date.parse(expiresAt) - this.now) / 1000));
  }

  get statusText() {
    if (!this.isWebhookTrigger || !this.webhookTestListener) {
      return null;
    }

    return i18n("discourse_workflows.webhook.listening_seconds", {
      seconds: this.expiresInSeconds,
    });
  }

  startCountdown() {
    if (isTesting()) {
      return;
    }

    if (this.countdownTimer) {
      return;
    }

    this.now = Date.now();
    this.countdownTimer = setInterval(() => {
      this.now = Date.now();
      if (!this.webhookTestListener) {
        this.stopCountdown();
      }
    }, 1000);
  }

  stopCountdown() {
    if (!this.countdownTimer) {
      return;
    }

    clearInterval(this.countdownTimer);
    this.countdownTimer = null;
  }

  <template>
    <ExpressionWrapper
      @field={{@field}}
      @schema={{@schema}}
      @supportsExpression={{@supportsExpression}}
      @placeholder={{@placeholder}}
      @dynamicValueHint={{@dynamicValueHint}}
      @session={{@session}}
    >
      {{#if this.isTestableTrigger}}
        <div class="workflows-url-preview-mode">
          <button
            type="button"
            class={{dConcatClass
              "workflows-url-preview-mode__button"
              (if (eq this.mode "test") "is-active")
            }}
            {{on "click" (fn this.setMode "test")}}
          >{{i18n "discourse_workflows.form.test_url"}}</button>
          <button
            type="button"
            class={{dConcatClass
              "workflows-url-preview-mode__button"
              (if (eq this.mode "production") "is-active")
            }}
            {{on "click" (fn this.setMode "production")}}
          >{{i18n "discourse_workflows.form.production_url"}}</button>
        </div>
      {{/if}}

      {{#if this.hasUrl}}
        {{! eslint-disable ember/template-no-invalid-interactive }}
        <div
          class={{dConcatClass
            "workflows-url-preview"
            (if this.copied "is-copied")
            (if this.isStartingTestSession "is-loading")
            (if this.isTestSessionUnavailable "is-disabled")
          }}
          title={{this.previewTitle}}
          {{on "click" this.previewAction}}
        >
          <code>{{this.previewText}}</code>
          {{dIcon this.previewIcon}}
        </div>
        {{#if this.statusText}}
          <div class="workflows-url-preview__status">
            <span>{{this.statusText}}</span>
            <button
              type="button"
              class="btn-link"
              {{on "click" this.cancelTestSession}}
            >{{i18n
                "discourse_workflows.webhook.cancel_test_listener"
              }}</button>
          </div>
        {{/if}}
      {{else if this.hint}}
        <p class="workflows-url-preview__hint">{{this.hint}}</p>
      {{/if}}
    </ExpressionWrapper>
  </template>
}
