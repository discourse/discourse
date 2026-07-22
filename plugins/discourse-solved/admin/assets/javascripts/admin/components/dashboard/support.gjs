import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DashboardSection from "discourse/admin/components/dashboard/section";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { durationTiny } from "discourse/lib/formatter";
import Category from "discourse/models/category";
import CategorySelector from "discourse/select-kit/components/category-selector";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import SupportResponseTime from "./support/response-time";
import SupportTopicOutcomes from "./support/topic-outcomes";
import SupportWhosAnswering from "./support/whos-answering";

const MAX_CATEGORIES = 10;

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
    const headline = this.data?.headline;
    if (!headline) {
      return null;
    }

    const prefix = "admin.dashboard.sections.support.headline";
    const titleKey = `${prefix}.${headline.key}.title`;

    if (headline.key === "no_data") {
      return { titleKey, summary: i18n(`${prefix}.no_data.summary`) };
    }

    const parts = [
      i18n(`${prefix}.resolution.${headline.resolution_direction}`, {
        rate: headline.resolution_rate,
      }),
    ];

    if (headline.answerers_focus) {
      parts.push(
        i18n(`${prefix}.answerers.${headline.answerers_focus}`, {
          share: headline.answerers_share,
        })
      );
    }

    if (headline.first_reply_seconds != null) {
      const dir = headline.first_reply_direction;
      if (
        (dir === "faster" || dir === "slower") &&
        headline.first_reply_delta_seconds != null
      ) {
        parts.push(
          i18n(`${prefix}.reply.${dir}`, {
            time: durationTiny(headline.first_reply_seconds),
            delta: durationTiny(headline.first_reply_delta_seconds),
          })
        );
      } else {
        parts.push(
          i18n(`${prefix}.reply.flat`, {
            time: durationTiny(headline.first_reply_seconds),
          })
        );
      }
    }

    if (headline.key === "struggling" && headline.unanswered_count > 0) {
      parts.push(
        i18n(`${prefix}.unanswered`, { count: headline.unanswered_count })
      );
    }

    return { titleKey, summary: parts.join(" ") };
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
              <h3>{{i18n this.headline.titleKey}}</h3>
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
            <CategorySelector
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
