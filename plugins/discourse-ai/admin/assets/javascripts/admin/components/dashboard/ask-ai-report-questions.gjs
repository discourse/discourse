import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import AskAiReportAnswer from "discourse/plugins/discourse-ai/admin/components/dashboard/ask-ai-report-answer";

export default class AskAiReportQuestions extends Component {
  @service modal;

  @tracked asks = [];
  @tracked failed = false;
  @tracked loading = false;
  @tracked nextBefore;
  @tracked visibleCount = 3;

  #inFlight = false;

  constructor() {
    super(...arguments);
    this.load();
  }

  get visibleAsks() {
    return this.asks.slice(0, this.visibleCount);
  }

  get hasMore() {
    return this.asks.length > this.visibleCount || this.nextBefore;
  }

  @action
  openAnswer(ask) {
    this.modal.show(AskAiReportAnswer, {
      model: {
        ask,
        reportId: this.args.reportId,
        subjectId: this.args.subjectId,
      },
    });
  }

  @action
  async showMore() {
    if (this.visibleCount >= this.asks.length) {
      await this.load();
    }
    this.visibleCount += 3;
  }

  @action
  async load() {
    if (this.#inFlight) {
      return;
    }
    this.#inFlight = true;
    this.loading = true;
    this.failed = false;
    try {
      const result = await ajax(
        `/admin/plugins/discourse-ai/ask-ai-reports/${this.args.reportId}/subjects/${this.args.subjectId}/asks`,
        { data: this.nextBefore ? { before: this.nextBefore } : {} }
      );
      if (!this.isDestroying) {
        this.asks = [...this.asks, ...result.asks];
        this.nextBefore = result.next_before;
      }
    } catch {
      if (!this.isDestroying) {
        this.failed = true;
      }
    } finally {
      this.#inFlight = false;
      if (!this.isDestroying) {
        this.loading = false;
      }
    }
  }

  <template>
    <div class="ask-ai-report-questions">
      <h4>{{i18n "admin.dashboard.ask_ai.reports.questions"}}</h4>
      <ul>
        {{#each this.visibleAsks key="id" as |ask|}}
          <li>
            <DButton
              class="btn-flat ask-ai-report-questions__query"
              @action={{fn this.openAnswer ask}}
              @translatedLabel={{ask.query}}
            />
          </li>
        {{/each}}
      </ul>
      {{#if this.loading}}
        <p role="status">{{i18n
            "admin.dashboard.ask_ai.reports.loading_questions"
          }}</p>
      {{else if this.failed}}
        <p role="alert">{{i18n
            "admin.dashboard.ask_ai.reports.questions_failed"
          }}</p>
        <DButton
          class="ask-ai-report-questions__retry"
          @action={{this.load}}
          @label="admin.dashboard.ask_ai.reports.retry_questions"
        />
      {{else if this.hasMore}}
        <DButton
          class="btn-flat ask-ai-report-questions__more"
          @action={{this.showMore}}
          @label="admin.dashboard.ask_ai.reports.more_questions"
        />
      {{else}}
        {{#unless this.asks.length}}
          <p>{{i18n "admin.dashboard.ask_ai.reports.no_questions"}}</p>
        {{/unless}}
      {{/if}}
    </div>
  </template>
}
