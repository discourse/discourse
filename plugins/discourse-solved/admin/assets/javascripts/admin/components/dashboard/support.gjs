import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DashboardSection from "discourse/admin/components/dashboard/section";
import { formatDashboardHeadlinePeriod } from "discourse/admin/lib/dashboard-format";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { durationTiny } from "discourse/lib/formatter";
import Category from "discourse/models/category";
import MultipleCategoriesSelector from "discourse/select-kit/components/multiple-categories-selector";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import SupportResponseTime from "./support/response-time";
import SupportTopicOutcomes from "./support/topic-outcomes";
import SupportWhosAnswering from "./support/whos-answering";

const MAX_CATEGORIES = 10;
const CTA_BY_SCENARIO = {
  up_up: "unanswered",
  up_flat: "unanswered",
  down_down: "in_progress",
  flat_down: "in_progress",
  down_up: "in_progress_and_unanswered",
  down_flat: "in_progress",
  flat_up: "unanswered",
  down_unavailable: "in_progress",
  unavailable_up: "unanswered",
};

const DeltaPill = <template>
  {{#if @delta.hasDelta}}
    {{#if (eq @delta.deltaClass "--neutral")}}
      <span class="db-pill">{{i18n "admin.dashboard.stable"}}</span>
    {{else}}
      <div class={{concat "db-delta " @delta.deltaClass}}>
        {{@delta.deltaText}}
      </div>
    {{/if}}
  {{/if}}
</template>;

export default class SupportSection extends Component {
  @service currentUser;
  @service siteSettings;
  @service toasts;

  @tracked selectedCategories = [];
  @tracked override = null;
  @tracked loading = false;

  constructor() {
    super(...arguments);

    this.selectedCategories = (this.args.data?.category_ids ?? [])
      .map((id) => Category.findById(id))
      .filter(Boolean);
    this.appliedCategoryIds = this.selectedCategories.map((c) => c.id);
  }

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

  get blockedCategories() {
    const allowedIds = new Set(
      (this.args.data?.category_options ?? []).map((option) => option.id)
    );
    return Category.list().filter((category) => !allowedIds.has(category.id));
  }

  get headline() {
    const resolutionDirection = this.#direction(
      this.data?.kpis?.resolution_rate
    );
    const replyDirection = this.#direction(this.data?.kpis?.avg_first_reply, {
      noPriorDirection: "up",
    });
    const prefix = "admin.dashboard.sections.support.headline";

    if (
      resolutionDirection === "unavailable" &&
      replyDirection === "unavailable"
    ) {
      return {
        title: i18n(`${prefix}.no_data.title`),
        summary: i18n(`${prefix}.no_data.summary`),
      };
    }

    const scenario = `${resolutionDirection}_${replyDirection}`;
    const period = formatDashboardHeadlinePeriod(this.args.period);
    const summary = i18n(`${prefix}.${scenario}.summary`);
    const ctaKey = CTA_BY_SCENARIO[scenario];
    const cta = ctaKey ? i18n(`${prefix}.cta.${ctaKey}`) : null;
    return {
      title: i18n(`${prefix}.${scenario}.title`, { period }),
      summary: cta ? `${summary} ${cta}` : summary,
    };
  }

  #direction(kpi, { noPriorDirection } = {}) {
    if (kpi?.value == null) {
      return "unavailable";
    }

    if (kpi.previous_value == null && noPriorDirection) {
      return noPriorDirection;
    }

    const previousValue = kpi.previous_value ?? 0;
    const roundedChange = Math.round(kpi.value - previousValue);
    if (roundedChange > 0) {
      return "up";
    } else if (roundedChange < 0) {
      return "down";
    }

    return "flat";
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
      deltaClass: diff === 0 ? "--neutral" : diff > 0 ? "--pos" : "--neg",
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
      deltaClass: diff === 0 ? "--neutral" : diff < 0 ? "--pos" : "--neg",
    };
  }

  get avgFirstReply() {
    const kpi = this.data?.kpis?.avg_first_reply ?? {};
    const value = kpi.value;
    const previous = kpi.previous_value;
    const hasDelta = value != null && previous != null;
    const diff = hasDelta ? value - previous : null;
    const slower = value > previous;
    return {
      value: value == null ? "—" : durationTiny(value),
      hasDelta,
      deltaText:
        !hasDelta || diff === 0
          ? null
          : `${slower ? "+" : "-"}${durationTiny(Math.abs(diff))}`,
      deltaClass: diff === 0 ? "--neutral" : slower ? "--neg" : "--pos",
    };
  }

  get appliedCategories() {
    return (this.data?.category_ids ?? [])
      .map((id) => Category.findById(id))
      .filter(Boolean);
  }

  get categoryFilterTerm() {
    if (this.appliedCategories.length > 0) {
      return this.#categoryTerm(this.appliedCategories);
    }

    if (this.siteSettings.allow_solved_on_all_topics) {
      return null;
    }

    const allSupport = (this.args.data?.category_options ?? [])
      .map((option) => Category.findById(option.id))
      .filter(Boolean);

    return allSupport.length > 0 ? this.#categoryTerm(allSupport) : null;
  }

  #categoryTerm(categories) {
    const slugs = categories.map((category) => Category.slugFor(category, ":"));
    // `=` restricts to these exact categories, excluding subcategories, to
    // match the dashboard's own count (accepted answers are opt-in per
    // category and never inherited by subcategories).
    return `=category:${slugs.join(",")}`;
  }

  get dateRangeTerms() {
    const terms = [];
    if (this.args.startDate) {
      terms.push(
        `created-after:${moment(this.args.startDate).format("YYYY-MM-DD")}`
      );
    }
    if (this.args.endDate) {
      // `created-before:D` matches created_at <= midnight on D, so pass the
      // following day to cover all of the selected end date (the dashboard's
      // own count instead runs through that day's end_of_day).
      terms.push(
        `created-before:${moment(this.args.endDate)
          .add(1, "day")
          .format("YYYY-MM-DD")}`
      );
    }
    return terms;
  }

  get outcomeQueries() {
    const statusTermsByRow = {
      resolved: ["status:solved"],
      in_progress: ["status:unsolved", "posts-min:2"],
      unanswered: ["status:unsolved", "status:noreplies"],
    };

    return Object.fromEntries(
      Object.entries(statusTermsByRow).map(([key, statusTerms]) => {
        const q = [
          ...statusTerms,
          ...this.dateRangeTerms,
          this.categoryFilterTerm,
        ]
          .filter(Boolean)
          .join(" ");
        return [key, { q }];
      })
    );
  }

  @action
  onCategoriesChange(categories) {
    this.selectedCategories = categories;
  }

  @action
  onClose() {
    const ids = this.selectedCategories.map((c) => c.id);
    const unchanged =
      ids.length === this.appliedCategoryIds.length &&
      ids.every((id) => this.appliedCategoryIds.includes(id));

    if (unchanged) {
      return;
    }

    this.appliedCategoryIds = ids;
    this.refetch();
    this.#persistSelection();
  }

  #persistSelection() {
    if (!this.currentUser?.admin) {
      return;
    }

    ajax("/admin/dashboard/sections/support/settings/categories.json", {
      type: "PUT",
      contentType: "application/json",
      data: JSON.stringify({
        category_ids: this.selectedCategories.map((c) => c.id),
      }),
    }).catch(() => {
      this.toasts.error({
        duration: "short",
        data: {
          message: i18n("admin.dashboard.sections.support.save_error"),
        },
      });
    });
  }

  @action
  onPeriodChange() {
    if (this.selectedCategories.length === 0) {
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
    const ids = this.selectedCategories.map((c) => c.id);
    if (ids.length > 0) {
      data.category_ids = ids.join(",");
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
              <h3>{{this.headline.title}}</h3>
              <p>{{this.headline.summary}}</p>
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
                <DeltaPill @delta={{this.resolutionRate}} />
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
                <DeltaPill @delta={{this.staffInvolvement}} />
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
                <DeltaPill @delta={{this.avgFirstReply}} />
              </div>
            </div>
          </div>
        {{/if}}

        {{#if this.showFilter}}
          <div class="db-support__filter">
            <MultipleCategoriesSelector
              @categories={{this.selectedCategories}}
              @blockedCategories={{this.blockedCategories}}
              @onChange={{this.onCategoriesChange}}
              @onClose={{this.onClose}}
              @options={{hash maximum=MAX_CATEGORIES none="category.all"}}
            />
          </div>
        {{/if}}

        <div class="db-section__row-group">
          <div class="db-section__row">
            <div class="db-section__row-block db-support-outcomes">
              <SupportTopicOutcomes
                @outcomes={{this.data.topic_outcomes}}
                @queries={{this.outcomeQueries}}
              />

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
