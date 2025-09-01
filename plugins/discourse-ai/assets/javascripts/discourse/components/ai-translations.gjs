import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import DPageSubheader from "discourse/components/d-page-subheader";
import DTooltip from "discourse/components/d-tooltip";
import InterpolatedTranslation from "discourse/components/interpolated-translation";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import AdminConfigAreaEmptyList from "admin/components/admin-config-area-empty-list";
import Chart from "admin/components/chart";

export default class AiTranslations extends Component {
  @service store;
  @service languageNameLookup;
  @service site;

  @tracked data = this.args.model?.translation_progress;
  @tracked done = this.args.model?.posts_with_detected_locale;
  @tracked total = this.args.model?.total;

  get descriptionKey() {
    return this.done === this.total
      ? "discourse_ai.translations.stats.complete_language_detection_description"
      : "discourse_ai.translations.stats.incomplete_language_detection_description";
  }

  get chartConfig() {
    if (!this.data || !this.data.length) {
      return {};
    }

    const chartEl = document.querySelector(".ai-translations");
    const backgroundColor = getComputedStyle(chartEl)
      .getPropertyValue("--chart-progress-color")
      .trim();

    const processedData = this.data.map(({ locale, total, done }) => {
      const donePercentage = (total > 0 ? (done / total) * 100 : 0).toFixed(0);
      return {
        locale: this.languageNameLookup.getLanguageName(locale),
        done,
        donePercentage,
        tooltip: [
          i18n("discourse_ai.translations.progress_chart.tooltip_translated", {
            done,
            total,
          }),
        ],
      };
    });
    const chartData = {
      labels: processedData.map(({ locale }) => locale),
      datasets: [
        {
          tooltip: processedData.map(({ tooltip }) => tooltip),
          data: processedData.map(({ donePercentage }) => donePercentage),
          totalItems: processedData.map(({ done }) => done),
          backgroundColor,
          barThickness: 30,
          borderRadius: 4,
        },
      ],
    };

    return {
      type: "bar",
      data: chartData,
      plugins: [
        {
          id: "barTotalText",
          afterDraw: ({ ctx, data, scales }) => {
            ctx.save();
            ctx.textBaseline = "middle";
            const items = data.datasets[0].totalItems;
            items.forEach((done, i) => {
              ctx.fillText(
                i18n("discourse_ai.translations.progress_chart.bar_done", {
                  done,
                }),
                scales.x.getPixelForValue(100) + 10,
                scales.y.getPixelForValue(i)
              );
            });
            ctx.canvas.parentElement.style.height = `${items.length * 50 + 40}px`;
            ctx.restore();
          },
        },
      ],
      options: {
        indexAxis: "y",
        responsive: true,
        maintainAspectRatio: false,
        layout: { padding: { right: 70 } },
        scales: {
          x: {
            beginAtZero: true,
            max: 100,
            grid: {
              display: false,
            },
            ticks: {
              callback: (percentage) =>
                i18n("discourse_ai.translations.progress_chart.data_label", {
                  percentage,
                }),
            },
          },
          y: {
            grid: {
              display: false,
            },
          },
        },
        plugins: {
          legend: { display: false },
          tooltip: {
            displayColors: false,
            callbacks: {
              label: ({ dataset: { tooltip }, dataIndex }) =>
                tooltip[dataIndex],
            },
          },
          datalabels: {
            formatter: (percentage) =>
              i18n("discourse_ai.translations.progress_chart.data_label", {
                percentage,
              }),
            color: "white",
          },
        },
      },
    };
  }

  <template>
    <div class="ai-translations admin-detail">
      <DPageSubheader
        @titleLabel={{i18n "discourse_ai.translations.title"}}
        @descriptionLabel={{i18n "discourse_ai.translations.description"}}
        @learnMoreUrl="https://meta.discourse.org/t/-/370969"
      >
        <:actions as |actions|>
          {{#if @model.enabled}}
            <actions.Default
              @label="discourse_ai.translations.admin_actions.translation_settings"
              @route="adminPlugins.show.discourse-ai-features.edit"
              @routeModels={{@model.translation_id}}
              class="ai-translation-settings-button"
            />
            <actions.Default
              @label="discourse_ai.translations.admin_actions.localization_settings"
              @route="adminConfig.localization.settings"
              class="ai-localization-settings-button"
            />
          {{/if}}
        </:actions>
      </DPageSubheader>

      {{#if @model.enabled}}
        <AdminConfigAreaCard
          class="ai-translation__charts"
          @heading="discourse_ai.translations.progress_chart.title"
        >
          <:content>
            <div class="ai-translation__stats-container">
              <div class="ai-translation__stat-item">
                <span class="ai-translation__stat-label">
                  <InterpolatedTranslation
                    @key={{this.descriptionKey}}
                    as |Placeholder|
                  >
                    <Placeholder @name="tooltip">
                      <DTooltip>
                        <:trigger>
                          {{icon "circle-question"}}
                        </:trigger>
                        <:content>
                          {{i18n
                            "discourse_ai.translations.stats.description_tooltip"
                          }}
                        </:content>
                      </DTooltip>
                    </Placeholder>
                    <Placeholder @name="done">{{this.done}}</Placeholder>
                    <Placeholder @name="total">{{this.total}}</Placeholder>
                  </InterpolatedTranslation>
                </span>
              </div>
            </div>
            <div class="ai-translation__chart-container">
              <Chart
                @chartConfig={{this.chartConfig}}
                @loadChartDataLabelsPlugin={{true}}
                class="ai-translation__chart"
              />
            </div>
          </:content>
        </AdminConfigAreaCard>
      {{else}}
        <AdminConfigAreaEmptyList
          @ctaLabel="discourse_ai.translations.admin_actions.disabled_state.configure"
          @ctaRoute="adminPlugins.show.discourse-ai-features.edit"
          @ctaRouteModels={{@model.translation_id}}
          @ctaClass="ai-translations__configure-button"
          @emptyLabel="discourse_ai.translations.admin_actions.disabled_state.empty_label"
        />
      {{/if}}

    </div>
  </template>
}
