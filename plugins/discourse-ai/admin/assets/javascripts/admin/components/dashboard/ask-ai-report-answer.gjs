import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import { i18n } from "discourse-i18n";

export default class AskAiReportAnswer extends Component {
  @tracked ask;
  @tracked failed = false;
  @tracked loading = true;

  constructor() {
    super(...arguments);
    this.load();
  }

  get outcome() {
    return i18n(
      `admin.dashboard.ask_ai.outcomes.${this.ask.ask_outcome || "pending"}`
    );
  }

  @action
  async load() {
    this.loading = true;
    this.failed = false;
    const { reportId, subjectId, ask } = this.args.model;
    try {
      const result = await ajax(
        `/admin/plugins/discourse-ai/ask-ai-reports/${reportId}/subjects/${subjectId}/asks/${ask.id}`
      );
      if (!this.isDestroying) {
        this.ask = result.ask;
      }
    } catch {
      if (!this.isDestroying) {
        this.failed = true;
      }
    } finally {
      if (!this.isDestroying) {
        this.loading = false;
      }
    }
  }

  <template>
    <DModal
      class="ask-ai-report-answer"
      @closeModal={{@closeModal}}
      @title={{i18n "admin.dashboard.ask_ai.reports.logged_answer"}}
    >
      <:body>
        <p class="ask-ai-report-answer__query">{{@model.ask.query}}</p>
        {{#if this.loading}}
          <p role="status">{{i18n
              "admin.dashboard.ask_ai.reports.loading_answer"
            }}</p>
        {{else if this.failed}}
          <p role="alert">{{i18n
              "admin.dashboard.ask_ai.reports.answer_failed"
            }}</p>
          <DButton
            @action={{this.load}}
            @label="admin.dashboard.ask_ai.reports.retry_questions"
          />
        {{else}}
          <p class="ask-ai-reports__hint">
            {{this.outcome}}
            ·
            {{dFormatDate this.ask.asked_at format="medium"}}
          </p>
          {{#if this.ask.answer}}
            {{#if this.ask.answer_title}}<h3
              >{{this.ask.answer_title}}</h3>{{/if}}
            <div class="ask-ai-report-answer__text">{{this.ask.answer}}</div>
          {{else}}
            <p>{{i18n "admin.dashboard.ask_ai.reports.no_stored_answer"}}</p>
          {{/if}}
        {{/if}}
      </:body>
    </DModal>
  </template>
}
