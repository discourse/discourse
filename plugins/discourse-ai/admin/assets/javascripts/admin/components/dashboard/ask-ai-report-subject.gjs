import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import AskAiReportQuestions from "discourse/plugins/discourse-ai/admin/components/dashboard/ask-ai-report-questions";

export default class AskAiReportSubject extends Component {
  @tracked expanded = false;

  get questionsId() {
    return `ask-ai-report-subject-${this.args.subject.id}`;
  }

  @action
  toggle() {
    this.expanded = !this.expanded;
  }

  <template>
    <div class="ask-ai-report-subject">
      <DButton
        aria-controls={{this.questionsId}}
        aria-expanded={{if this.expanded "true" "false"}}
        class="btn-flat ask-ai-report-subject__toggle"
        @action={{this.toggle}}
        @icon={{if this.expanded "chevron-down" "chevron-right"}}
      >
        <span class="ask-ai-report-subject__label">
          <strong>{{@subject.name}}</strong>
          <span
            class="ask-ai-report-subject__description"
          >{{@subject.description}}</span>
        </span>
        <span class="ask-ai-report-subject__count">{{i18n
            "admin.dashboard.ask_ai.reports.subject_count"
            count=@subject.ask_count
          }}</span>
      </DButton>
      <div hidden={{unless this.expanded true}} id={{this.questionsId}}>
        {{#if this.expanded}}
          <AskAiReportQuestions
            @reportId={{@reportId}}
            @subjectId={{@subject.id}}
          />
        {{/if}}
      </div>
    </div>
  </template>
}
