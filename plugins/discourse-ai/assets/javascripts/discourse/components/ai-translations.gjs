import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DPageSubheader from "discourse/components/d-page-subheader";
import { i18n } from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import Chart from "admin/components/chart";
import { service } from "@ember/service";

export default class AiTranslations extends Component {
  @service siteSettings;

  @tracked loadingData = false;
  @tracked data = this.args.model?.ai_translations;

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
      const total = item.completion_percentage + item.todo_count;
      return {
        locale: this.getLanguageName(item.locale),
        completionPercentage: (item.completion_percentage / total) * 100,
        remainingPercentage: (item.todo_count / total) * 100,
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
        barThickness: 40,
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
      />
    </div>

    <ConditionalLoadingSpinner @condition={{this.loadingData}}>
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
    </ConditionalLoadingSpinner>
  </template>
}
