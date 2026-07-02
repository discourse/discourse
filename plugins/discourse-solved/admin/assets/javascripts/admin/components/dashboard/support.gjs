import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { LinkTo } from "@ember/routing";
import DashboardSection from "discourse/admin/components/dashboard/section";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { durationTiny } from "discourse/lib/formatter";
import ComboBox from "discourse/select-kit/components/combo-box";
import { i18n } from "discourse-i18n";
import SupportResponseTime from "./support/response-time";
import SupportTopicOutcomes from "./support/topic-outcomes";
import SupportWhosAnswering from "./support/whos-answering";

const ALL_CATEGORIES = "all";

export default class SupportSection extends Component {
  @tracked categoryId = ALL_CATEGORIES;
  @tracked override = null;
  @tracked loading = false;

  // The active payload: the category-filtered refetch when present, otherwise
  // the data supplied by the main dashboard request.
  get data() {
    return this.override ?? this.args.data;
  }

  // The filter is driven by the unfiltered payload so it stays put while a
  // category is selected; it's hidden when there's at most one support category.
  get showFilter() {
    return (this.args.data?.category_options?.length ?? 0) > 1;
  }

  get categoryOptions() {
    return [
      {
        id: ALL_CATEGORIES,
        name: i18n("admin.dashboard.sections.support.filter.all_categories"),
      },
      ...(this.args.data?.category_options ?? []),
    ];
  }

  get headline() {
    const headline = this.data?.headline;
    if (!headline) {
      return null;
    }
    return {
      titleKey: `admin.dashboard.sections.support.headline.${headline.key}.title`,
      summaryKey: `admin.dashboard.sections.support.headline.${headline.key}.summary`,
      summaryArgs: {
        resolution_rate: headline.resolution_rate,
        count: headline.unanswered_count,
      },
    };
  }

  get resolutionRate() {
    const kpi = this.data?.kpis?.resolution_rate ?? {};
    const value = kpi.value ?? 0;
    const previous = kpi.previous_value;
    const diff = previous == null ? null : Math.round(value - previous);
    return {
      value: `${Math.round(value)}%`,
      reportType: kpi.report_type,
      reportQuery: kpi.report_query ?? {},
      hasDelta: diff != null,
      deltaText: diff == null ? null : `${diff > 0 ? "+" : ""}${diff}%`,
      deltaClass: diff >= 0 ? "--pos" : "--neg",
    };
  }

  get staffInvolvement() {
    const kpi = this.data?.kpis?.staff_involvement ?? {};
    const value = kpi.value ?? 0;
    const previous = kpi.previous_value;
    const diff = previous == null ? null : Math.round(value - previous);
    return {
      value: `${Math.round(value)}%`,
      hasDelta: diff != null,
      deltaText: diff == null ? null : `${diff > 0 ? "+" : ""}${diff}%`,
      deltaClass: diff <= 0 ? "--pos" : "--neg",
    };
  }

  get avgFirstReply() {
    const kpi = this.data?.kpis?.avg_first_reply ?? {};
    const value = kpi.value;
    const previous = kpi.previous_value;
    const hasDelta = value != null && previous != null && value !== previous;
    const slower = value > previous;
    return {
      value: value == null ? "—" : durationTiny(value),
      hasDelta,
      deltaText: hasDelta
        ? `${slower ? "+" : "-"}${durationTiny(Math.abs(value - previous))}`
        : null,
      deltaClass: slower ? "--neg" : "--pos",
    };
  }

  @action
  onCategoryChange(categoryId) {
    this.categoryId = categoryId;
    this.refetch();
  }

  @action
  onPeriodChange() {
    if (this.categoryId === ALL_CATEGORIES) {
      this.override = null;
    } else {
      this.refetch();
    }
  }

  async refetch() {
    this.loading = true;

    const data = {};
    if (this.args.startDate) {
      data.start_date = moment(this.args.startDate).format("YYYY-MM-DD");
    }
    if (this.args.endDate) {
      data.end_date = moment(this.args.endDate).format("YYYY-MM-DD");
    }
    if (this.categoryId !== ALL_CATEGORIES) {
      data.category_id = this.categoryId;
    }

    try {
      this.override = await ajax(
        "/admin/plugins/solved/dashboard-support.json",
        {
          data,
        }
      );
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  <template>
    <DashboardSection
      @title={{i18n "admin.dashboard.sections.support.title"}}
      @startDate={{@startDate}}
      @endDate={{@endDate}}
      ...attributes
      {{didUpdate this.onPeriodChange @startDate @endDate}}
    >
      {{#if @fetchError}}
        <div class="db-section__error" role="alert">
          {{i18n "admin.dashboard.sections.support.fetch_error"}}
        </div>
      {{else}}
        {{#if this.headline}}
          <div class="db-section__subheader">
            <div class="db-section__subintro">
              <h3>{{i18n this.headline.titleKey}}</h3>
              <p>{{i18n this.headline.summaryKey this.headline.summaryArgs}}</p>
            </div>

            <div class="db-section__metrics">
              <div class="db-section__metric">
                <div class="db-section__metric-number">
                  {{this.resolutionRate.value}}
                </div>
                <div class="db-section__metric-label">
                  <LinkTo
                    @route="adminReports.show"
                    @model={{this.resolutionRate.reportType}}
                    @query={{this.resolutionRate.reportQuery}}
                  >
                    {{i18n
                      "admin.dashboard.sections.support.kpi.resolution_rate.label"
                    }}
                  </LinkTo>
                  <DTooltip
                    class="db-section__info"
                    @icon="far-circle-question"
                    @content={{i18n
                      "admin.dashboard.sections.support.kpi.resolution_rate.tooltip"
                    }}
                  />
                </div>
                {{#if this.resolutionRate.hasDelta}}
                  <div
                    class={{concat "db-delta " this.resolutionRate.deltaClass}}
                  >
                    {{this.resolutionRate.deltaText}}
                  </div>
                {{/if}}
              </div>

              <div class="db-section__metric">
                <div class="db-section__metric-number">
                  {{this.staffInvolvement.value}}
                </div>
                <div class="db-section__metric-label">
                  {{i18n
                    "admin.dashboard.sections.support.kpi.staff_involvement.label"
                  }}
                  <DTooltip
                    class="db-section__info"
                    @icon="far-circle-question"
                    @content={{i18n
                      "admin.dashboard.sections.support.kpi.staff_involvement.tooltip"
                    }}
                  />
                </div>
                {{#if this.staffInvolvement.hasDelta}}
                  <div
                    class={{concat
                      "db-delta "
                      this.staffInvolvement.deltaClass
                    }}
                  >
                    {{this.staffInvolvement.deltaText}}
                  </div>
                {{/if}}
              </div>

              <div class="db-section__metric">
                <div class="db-section__metric-number">
                  {{this.avgFirstReply.value}}
                </div>
                <div class="db-section__metric-label">
                  {{i18n
                    "admin.dashboard.sections.support.kpi.avg_first_reply.label"
                  }}
                  <DTooltip
                    class="db-section__info"
                    @icon="far-circle-question"
                    @content={{i18n
                      "admin.dashboard.sections.support.kpi.avg_first_reply.tooltip"
                    }}
                  />
                </div>
                {{#if this.avgFirstReply.hasDelta}}
                  <div
                    class={{concat "db-delta " this.avgFirstReply.deltaClass}}
                  >
                    {{this.avgFirstReply.deltaText}}
                  </div>
                {{/if}}
              </div>
            </div>
          </div>
        {{/if}}

        {{#if this.showFilter}}
          <div class="db-support__filter">
            <ComboBox
              @content={{this.categoryOptions}}
              @value={{this.categoryId}}
              @onChange={{this.onCategoryChange}}
              @valueProperty="id"
              @nameProperty="name"
            />
          </div>
        {{/if}}

        <div class="db-section__row-group">
          <div class="db-section__row">
            <div class="db-section__row-block db-support-outcomes">
              <SupportTopicOutcomes @outcomes={{this.data.topic_outcomes}} />

            </div>
            <div class="db-section__row-block db-support-response">
              <SupportResponseTime
                @data={{this.data.response_time_distribution}}
              />
            </div>
          </div>

          <div class="db-section__row">
            <div class="db-section__row-block db-support-answerers">
              <SupportWhosAnswering @data={{this.data.whos_answering}} />
            </div>
            <div class="db-section__row-block"></div>
          </div>
        </div>
      {{/if}}
    </DashboardSection>
  </template>
}
