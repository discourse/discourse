import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AskAiReportSubject from "discourse/plugins/discourse-ai/admin/components/dashboard/ask-ai-report-subject";

export default class AskAiReportSubjects extends Component {
  @tracked showAll = false;

  get subjects() {
    return this.showAll
      ? this.args.report.subjects
      : this.args.report.subjects.slice(0, 3);
  }

  get hasMore() {
    return this.args.report.subjects.length > 3;
  }

  get reportURL() {
    return getURL(this.args.report.topic_url);
  }

  @action
  toggleAll() {
    this.showAll = !this.showAll;
  }

  <template>
    <div class="ask-ai-report-subjects">
      {{#if @report.summary}}
        <p class="ask-ai-report-subjects__summary">{{@report.summary}}</p>
      {{/if}}
      {{#each this.subjects key="id" as |subject|}}
        <AskAiReportSubject @reportId={{@report.id}} @subject={{subject}} />
      {{/each}}
      <div class="ask-ai-report-subjects__footer">
        <div class="ask-ai-report-subjects__actions">
          {{#if this.hasMore}}
            <DButton
              class="btn-flat ask-ai-report-subjects__show-all"
              @action={{this.toggleAll}}
              @translatedLabel={{if
                this.showAll
                (i18n "admin.dashboard.ask_ai.reports.show_fewer")
                (i18n
                  "admin.dashboard.ask_ai.reports.show_all"
                  count=@report.subjects.length
                )
              }}
            />
          {{/if}}
          {{#if @report.topic_url}}
            <a
              aria-label={{i18n
                "admin.dashboard.ask_ai.reports.view_pm_new_tab"
              }}
              class="ask-ai-report-subjects__report-link"
              href={{this.reportURL}}
              rel="noopener noreferrer"
              target="_blank"
            >
              {{i18n "admin.dashboard.ask_ai.reports.view_pm"}}
              {{dIcon "up-right-from-square"}}
            </a>
          {{/if}}
        </div>
        <span class="ask-ai-reports__hint">{{i18n
            "admin.dashboard.ask_ai.reports.coverage"
            count=@report.reported_ask_count
            total=@report.total_ask_count
          }}
          ·
          {{i18n "admin.dashboard.ask_ai.reports.overlap"}}</span>
      </div>
    </div>
  </template>
}
