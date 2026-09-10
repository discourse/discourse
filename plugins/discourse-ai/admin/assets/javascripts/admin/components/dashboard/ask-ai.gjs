import Component from "@glimmer/component";
import AdminReportChart from "discourse/admin/components/admin-report-chart";
import DashboardSection from "discourse/admin/components/dashboard/section";
import Report from "discourse/admin/models/report";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import getURL from "discourse/lib/get-url";
import { or } from "discourse/truth-helpers";
import I18n, { i18n } from "discourse-i18n";

const copy = (key) => i18n(`admin.dashboard.ask_ai.${key}`);
const count = (value) => I18n.toNumber(value, { precision: 0 });
const outcomeLabel = (value) => copy(`outcomes.${value}`);

export default class AskAiDashboard extends Component {
  get activityQueryUrl() {
    return this.#queryUrl("activity");
  }

  get outcomesQueryUrl() {
    return this.#queryUrl("outcomes");
  }

  get averageFirstAnswer() {
    const value = this.args.data?.average_first_answer_ms;
    return value == null
      ? copy("not_available")
      : i18n("admin.dashboard.ask_ai.seconds", {
          seconds: I18n.toNumber(value / 1000, { precision: 1 }),
        });
  }

  get chartModel() {
    return {
      start_date: this.args.data.start_date,
      end_date: this.args.data.end_date,
      data: this.args.data.daily_asks ?? [],
    };
  }

  get chartOptions() {
    return {
      chartGrouping: Report.groupingForDatapoints(
        this.args.data.daily_asks?.length ?? 0
      ),
    };
  }

  get outcomes() {
    return (this.args.data.outcomes ?? [])
      .filter((outcome) => outcome.count > 0)
      .map((outcome) => ({
        ...outcome,
        percentage: I18n.toNumber(
          (outcome.count / this.args.data.questions) * 100,
          { precision: 1 }
        ),
      }));
  }

  #queryUrl(type) {
    const id = this.args.data?.data_explorer_query_ids?.[type];
    if (!id) {
      return;
    }
    const params = encodeURIComponent(
      JSON.stringify({
        start_date: this.args.data.start_date,
        end_date: this.args.data.end_date,
      })
    );
    return getURL(
      `/admin/plugins/discourse-data-explorer/queries/${id}?params=${params}`
    );
  }

  <template>
    {{#if (or @data @fetchError)}}
      <DashboardSection
        class="ask-ai-dashboard"
        ...attributes
        @title={{copy "title"}}
      >
        {{#if @fetchError}}
          <p class="db-section__error" role="alert">{{copy "fetch_error"}}</p>
        {{else}}
          <div class="db-section__subheader">
            <div class="db-section__subintro">
              <h3>
                {{#if @data.questions}}
                  {{i18n
                    "admin.dashboard.ask_ai.summary"
                    count=@data.questions
                  }}
                {{else}}
                  {{copy "empty"}}
                {{/if}}
              </h3>
            </div>
            <dl
              aria-busy={{@loading}}
              class="db-section__metrics ask-ai-dashboard__metrics"
            >
              <div
                class="db-section__metric ask-ai-dashboard__metric"
                data-metric="questions"
              >
                <dt class="db-section__metric-label">{{copy "questions"}}</dt>
                <dd class="db-section__metric-number">{{count
                    @data.questions
                  }}</dd>
              </div>
              <div
                class="db-section__metric ask-ai-dashboard__metric"
                data-metric="askers"
              >
                <dt class="db-section__metric-label">{{copy "askers"}}</dt>
                <dd class="db-section__metric-number">{{count
                    @data.askers
                  }}</dd>
              </div>
              <div
                class="db-section__metric ask-ai-dashboard__metric"
                data-metric="latency"
              >
                <dt class="db-section__metric-label">
                  {{copy "latency"}}
                  <DTooltip
                    class="db-section__info"
                    @icon="far-circle-question"
                    @identifier="ask-ai-answer-time-tooltip"
                  >
                    <:content>{{copy "latency_tooltip"}}</:content>
                  </DTooltip>
                </dt>
                <dd
                  class="db-section__metric-number"
                >{{this.averageFirstAnswer}}</dd>
              </div>
            </dl>
          </div>
          {{#if @data.questions}}
            <div class="db-section__row ask-ai-dashboard__activity">
              <section
                aria-label={{copy "activity"}}
                class="db-section__row-block ask-ai-dashboard__chart"
              >
                <h3 class="db-section__row-block-title">
                  {{#if this.activityQueryUrl}}<a
                      href={{this.activityQueryUrl}}
                    >{{copy "activity"}}</a>{{else}}{{copy "activity"}}{{/if}}
                </h3>
                <AdminReportChart
                  @model={{this.chartModel}}
                  @options={{this.chartOptions}}
                />
                <div class="sr-only">
                  <table>
                    <caption>{{copy "activity"}}</caption>
                    <thead><tr><th scope="col">{{copy "date"}}</th><th
                          scope="col"
                        >{{copy "questions"}}</th></tr></thead>
                    <tbody>
                      {{#each @data.daily_asks as |day|}}
                        <tr><th scope="row">{{day.x}}</th><td>{{count
                              day.y
                            }}</td></tr>
                      {{/each}}
                    </tbody>
                  </table>
                </div>
              </section>
              <section class="db-section__row-block ask-ai-dashboard__outcomes">
                <h3 class="db-section__row-block-title">
                  {{#if this.outcomesQueryUrl}}<a
                      href={{this.outcomesQueryUrl}}
                    >{{copy "outcomes_title"}}</a>{{else}}{{copy
                      "outcomes_title"
                    }}{{/if}}
                  <DTooltip
                    class="db-section__info"
                    @icon="far-circle-question"
                    @identifier="ask-ai-outcomes-tooltip"
                  >
                    <:content>{{copy "outcome_note"}}</:content>
                  </DTooltip>
                </h3>
                <dl class="ask-ai-dashboard__list">
                  {{#each this.outcomes as |outcome|}}
                    <div data-outcome={{outcome.outcome}}>
                      <dt>{{outcomeLabel outcome.outcome}}</dt>
                      <dd>
                        {{count outcome.count}}
                        <span class="ask-ai-dashboard__percentage">{{i18n
                            "admin.dashboard.ask_ai.percentage"
                            value=outcome.percentage
                          }}</span>
                      </dd>
                    </div>
                  {{/each}}
                </dl>
              </section>
            </div>
          {{/if}}
        {{/if}}
      </DashboardSection>
    {{/if}}
  </template>
}
