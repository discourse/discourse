import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import DPageSubheader from "discourse/components/d-page-subheader";
import { i18n } from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import AdminConfigAreaEmptyList from "admin/components/admin-config-area-empty-list";
import Chart from "admin/components/chart";

export default class AiTranslations extends Component {
  @service siteSettings;
  @service store;

  @tracked data = this.args.model?.translation_progress;

  getLanguageName(locale) {
    try {
      const availableLocales = this.siteSettings.available_locales;
      const localeObj = availableLocales.find((l) => l.value === locale);
      return localeObj ? localeObj.name : locale;
    } catch {
      return locale; // Fallback to the locale code if not found
    }
  }

  get chartConfig() {
    if (!this.data || !this.data.length) {
      return {};
    }

    const chartEl = document.querySelector(".ai-translations");
    const computedStyle = getComputedStyle(chartEl);
    const colors = {
      progress: computedStyle.getPropertyValue("--chart-progress-color").trim(),
      remaining: computedStyle
        .getPropertyValue("--chart-remaining-color")
        .trim(),
    };

    const processedData = this.data.map((item) => {
      return {
        locale: this.getLanguageName(item.locale),
        completionPercentage: item.completion_percentage,
        remainingPercentage: item.remaining_percentage,
      };
    });

    return {
      type: "bar",
      data: {
        labels: processedData.map((item) => item.locale),
        datasets: [
          {
            label: i18n("discourse_ai.translations.progress_chart.completed"),
            data: processedData.map((item) => item.completionPercentage),
            backgroundColor: colors.progress,
          },
          {
            label: i18n("discourse_ai.translations.progress_chart.remaining"),
            data: processedData.map((item) => item.remainingPercentage),
            backgroundColor: colors.remaining,
          },
        ],
      },
      options: {
        indexAxis: "y",
        responsive: true,
        scales: {
          x: {
            stacked: true,
            beginAtZero: true,
            max: 100,
            ticks: {
              callback: (value) => `${value}%`,
            },
          },
          y: {
            stacked: true,
          },
        },
        plugins: {
          tooltip: {
            callbacks: {
              label: (context) =>
                `${context.dataset.label}: ${context.raw.toFixed(1)}%`,
            },
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
            <div class="ai-translation__chart-container">
              <Chart
                @chartConfig={{this.chartConfig}}
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
