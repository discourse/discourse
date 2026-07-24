import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import moment from "moment";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import Chart from "discourse/admin/components/chart";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Category from "discourse/models/category";
import CategorySelector from "discourse/select-kit/components/category-selector";
import ComboBox from "discourse/select-kit/components/combo-box";
import MultiSelect from "discourse/select-kit/components/multi-select";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class AiTranslations extends Component {
  @service aiCredits;
  @service router;
  @service languageNameLookup;
  @service site;
  @service siteSettings;

  @tracked data = null;
  @tracked done = null;
  @tracked total = null;
  @tracked loadingProgress = false;
  @tracked progressCachedAt = null;
  @tracked
  translationEnabled =
    this.args.model?.translation_enabled &&
    !this.args.model?.no_locales_configured;
  @tracked enabled = this.args.model?.enabled;
  @tracked
  selectedLocales = this.siteSettings.content_localization_supported_locales
    ? this.siteSettings.content_localization_supported_locales.split("|")
    : [];
  @tracked
  originalLocales = this.siteSettings.content_localization_supported_locales
    ? this.siteSettings.content_localization_supported_locales.split("|")
    : [];
  @tracked isSavingLocales = false;
  @tracked isSavingCategories = false;
  @tracked isTogglingTranslation = false;
  @tracked creditStatus = null;
  @tracked creditCheckComplete = false;
  @tracked categoryScope = this.args.model?.category_scope || "public";
  @tracked originalCategoryScope = this.args.model?.category_scope || "public";
  @tracked categories = [];
  @tracked originalCategoryIds = this.args.model?.category_ids || [];
  hourlyRate = this.args.model?.hourly_rate || 0;

  constructor() {
    super(...arguments);
    this._checkCredits();
    this._loadCategories();
    if (this.enabled) {
      this._loadProgress();
    }
  }

  async _loadCategories() {
    const ids = this.args.model?.category_ids || [];
    if (ids.length) {
      this.categories = await Category.asyncFindByIds(ids);
    }
  }

  async _loadProgress() {
    this.loadingProgress = true;
    try {
      const response = await ajax(
        "/admin/plugins/discourse-ai/ai-translations/progress.json"
      );
      this.data = response.translation_progress;
      this.total = response.total;
      this.done = response.posts_with_detected_locale;
      this.progressCachedAt = response.cached_at;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loadingProgress = false;
    }
  }

  async _checkCredits() {
    try {
      this.creditStatus =
        await this.aiCredits.getFeatureCreditStatus("locale_detector");
    } catch {
      this.creditStatus = null;
    }
    this.creditCheckComplete = true;
  }

  get creditLimitReached() {
    return this.creditStatus?.hard_limit_reached === true;
  }

  get creditLimitWarningMessage() {
    if (!this.creditLimitReached) {
      return null;
    }
    const resetTime =
      this.creditStatus?.reset_time_formatted ||
      this.creditStatus?.reset_time_absolute;
    if (resetTime) {
      return trustHTML(
        i18n("discourse_ai.translations.credit_limit_warning", {
          reset_time: resetTime,
        })
      );
    }
    return trustHTML(
      i18n("discourse_ai.translations.credit_limit_warning_no_time")
    );
  }

  get localesChanged() {
    const current = [...this.selectedLocales].sort().join("|");
    const original = [...this.originalLocales].sort().join("|");
    return current !== original;
  }

  get categoriesChanged() {
    const current = [...this.categories.map((category) => category.id)]
      .sort()
      .join("|");
    const original = [...this.originalCategoryIds].sort().join("|");
    return (
      this.categoryScope !== this.originalCategoryScope || current !== original
    );
  }

  get categoryScopeOptions() {
    return [
      "all",
      "public",
      "include",
      "include_strict",
      "exclude",
      "exclude_strict",
    ].map((value) => ({
      value,
      name: i18n(`category_scope.${value}`),
    }));
  }

  get showCategorySelector() {
    return ["include", "include_strict", "exclude", "exclude_strict"].includes(
      this.categoryScope
    );
  }

  get isToggleDisabled() {
    return (
      this.isTogglingTranslation ||
      (this.args.model?.no_locales_configured &&
        this.originalLocales.length === 0)
    );
  }

  get availableLocales() {
    const locales = this.siteSettings.available_locales;
    if (!locales) {
      return [];
    }

    return locales;
  }

  get settingsUrl() {
    return this.router.urlFor(
      "adminPlugins.show.discourse-ai-features.edit",
      this.args.model.translation_id
    );
  }

  @action
  navigateToLocalizationSettings() {
    this.router.transitionTo("adminConfig.localization.settings", {
      queryParams: { filter: "content_localization_supported_locales" },
    });
  }

  @action
  updateSelectedLocales(locales) {
    this.selectedLocales = locales;
  }

  @action
  async saveLocales() {
    this.isSavingLocales = true;
    try {
      // also enable content_localization_enabled when we're setting locales
      if (this.selectedLocales.length > 0) {
        await ajax("/admin/site_settings/content_localization_enabled", {
          type: "PUT",
          data: { content_localization_enabled: true },
        });
      }

      await ajax(
        "/admin/site_settings/content_localization_supported_locales",
        {
          type: "PUT",
          data: {
            content_localization_supported_locales:
              this.selectedLocales.join("|"),
          },
        }
      );
      this.originalLocales = [...this.selectedLocales];

      if (this.selectedLocales.length > 0) {
        this.args.model.no_locales_configured = false;
      }

      if (this.translationEnabled) {
        window.location.reload();
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isSavingLocales = false;
    }
  }

  @action
  cancelLocales() {
    this.selectedLocales = [...this.originalLocales];
  }

  @action
  resetLocales() {
    this.selectedLocales = [];
  }

  @action
  updateCategoryScope(scope) {
    this.categoryScope = scope;
  }

  @action
  updateCategories(categories) {
    this.categories = categories;
  }

  @action
  async saveCategories() {
    this.isSavingCategories = true;
    try {
      const ids = this.categories.map((category) => category.id);
      await ajax("/admin/site_settings/bulk_update", {
        type: "PUT",
        data: {
          settings: {
            ai_translation_category_scope: { value: this.categoryScope },
            ai_translation_categories: { value: ids.join("|") },
          },
        },
      });
      this.originalCategoryScope = this.categoryScope;
      this.originalCategoryIds = ids;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isSavingCategories = false;
    }
  }

  @action
  async cancelCategories() {
    this.categoryScope = this.originalCategoryScope;
    this.categories = await Category.asyncFindByIds(this.originalCategoryIds);
  }

  @action
  resetCategories() {
    this.categoryScope = "public";
    this.categories = [];
  }

  @action
  async toggleTranslationEnabled() {
    if (this.isTogglingTranslation) {
      return;
    }

    if (!this.translationEnabled && this.originalLocales.length === 0) {
      return;
    }

    this.isTogglingTranslation = true;
    try {
      if (!this.translationEnabled && this.originalLocales.length > 0) {
        await ajax("/admin/site_settings/content_localization_enabled", {
          type: "PUT",
          data: { content_localization_enabled: true },
        });
      }

      await ajax("/admin/site_settings/ai_translation_enabled", {
        type: "PUT",
        data: { ai_translation_enabled: !this.translationEnabled },
      });
      this.translationEnabled = !this.translationEnabled;

      if (this.translationEnabled && !this.args.model.no_locales_configured) {
        this.enabled = true;
        this._loadProgress();
      } else {
        this.enabled = false;
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isTogglingTranslation = false;
    }
  }

  get chartRightPadding() {
    const max = Math.max(...this.data.map(({ total }) => total));
    switch (true) {
      case max >= 100000:
        return 90;
      case max >= 10000:
        return 80;
      case max >= 20:
        return 70;
      default:
        return 50;
    }
  }

  get backfillStatusMessage() {
    if (
      this.args.model?.backfill_enabled &&
      this.args.model?.backfill_max_age_days &&
      this.hourlyRate > 0
    ) {
      const totalRemaining = this.data?.reduce(
        (sum, { total, done }) => sum + (total - done),
        0
      );

      if (totalRemaining && totalRemaining > 0) {
        const cutoffDate = new Date();
        cutoffDate.setDate(
          cutoffDate.getDate() - this.args.model.backfill_max_age_days
        );

        const formattedDate = cutoffDate.toLocaleDateString(undefined, {
          year: "numeric",
          month: "long",
          day: "numeric",
        });

        return trustHTML(
          i18n("discourse_ai.translations.stats.backfill_message", {
            date: formattedDate,
            settingsUrl: this.settingsUrl,
          })
        );
      }
    }

    if (!this.args.model?.backfill_enabled) {
      return i18n("discourse_ai.translations.stats.backfill_disabled");
    }

    return null;
  }

  get cachedResultsNotice() {
    if (!this.progressCachedAt) {
      return null;
    }

    return i18n("discourse_ai.translations.cached_results_notice", {
      relative_time: moment(this.progressCachedAt).fromNow(),
    });
  }

  get chartColors() {
    const styles = getComputedStyle(document.querySelector(".ai-translations"));
    return {
      progress: styles.getPropertyValue("--chart-progress-color").trim(),
      remaining: styles.getPropertyValue("--chart-remaining-color").trim(),
      text: styles.getPropertyValue("--chart-text-color").trim(),
      label: styles.getPropertyValue("--chart-label-color").trim(),
    };
  }

  get chartConfig() {
    if (!this.data?.length) {
      return {};
    }

    const colors = this.chartColors;
    const processedData = this.data.map(({ locale, total, done }) => {
      const rawPercentage = total > 0 ? (done / total) * 100 : 0;
      const donePercentage = Math.trunc(rawPercentage).toString();
      const localeName = this.languageNameLookup.getLanguageName(locale);
      const languageNameForTooltip = localeName.split(" (")[0];

      return {
        locale: localeName,
        done,
        total,
        donePercentage,
        tooltip: [
          i18n("discourse_ai.translations.progress_chart.tooltip_translated", {
            done,
            total,
            language: languageNameForTooltip,
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
          totalItems: processedData.map(({ total }) => total),
          backgroundColor: colors.progress,
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
            ctx.fillStyle = colors.text;
            const items = data.datasets[0].totalItems;
            items.forEach((count, i) => {
              ctx.fillText(
                i18n("discourse_ai.translations.progress_chart.bar_done", {
                  count,
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
        layout: { padding: { right: this.chartRightPadding } },
        scales: {
          x: {
            beginAtZero: true,
            max: 100,
            grid: {
              display: false,
            },
            ticks: {
              color: colors.text,
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
            ticks: {
              color: colors.text,
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
              this.site.mobileView && percentage < 20
                ? ""
                : i18n("discourse_ai.translations.progress_chart.data_label", {
                    percentage,
                  }),
            color: colors.label,
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
        </:actions>
      </DPageSubheader>

      {{#if this.creditLimitReached}}
        <div class="alert alert-warning ai-translations__credit-warning">
          {{dIcon "triangle-exclamation"}}
          <span>{{this.creditLimitWarningMessage}}</span>
        </div>
      {{/if}}

      <div class="ai-translations__settings-panel settings">
        <div class="setting ai-translations__toggle-container">
          <DToggleSwitch
            @state={{this.translationEnabled}}
            @label="discourse_ai.translations.admin_actions.enable_translations"
            disabled={{this.isToggleDisabled}}
            {{on "click" this.toggleTranslationEnabled}}
          />
        </div>
        <div class="ai-translations__settings-fields">
          <div class="setting">
            <div class="setting-label">
              <label>{{i18n
                  "discourse_ai.translations.supported_locales"
                }}</label>
            </div>
            <div class="setting-value">
              <div class="ai-translations__locale-input-row">
                <MultiSelect
                  @value={{this.selectedLocales}}
                  @content={{this.availableLocales}}
                  @nameProperty="name"
                  @valueProperty="value"
                  @onChange={{this.updateSelectedLocales}}
                  @options={{hash allowAny=false}}
                />
                {{#if this.localesChanged}}
                  <div class="setting-controls">
                    <DButton
                      @action={{this.saveLocales}}
                      @icon="check"
                      @isLoading={{this.isSavingLocales}}
                      @ariaLabel="save"
                      class="ok setting-controls__ok"
                    />
                    <DButton
                      @action={{this.cancelLocales}}
                      @icon="xmark"
                      @isLoading={{this.isSavingLocales}}
                      @ariaLabel="cancel"
                      class="cancel setting-controls__cancel"
                    />
                  </div>
                {{else if this.selectedLocales.length}}
                  <DButton
                    @action={{this.resetLocales}}
                    @icon="arrow-rotate-left"
                    @label="admin.settings.reset"
                    class="undo setting-controls__undo"
                  />
                {{/if}}
              </div>
            </div>
          </div>
          <div class="setting">
            <div class="setting-label">
              <label>{{i18n "discourse_ai.translations.category_scope"}}</label>
            </div>
            <div class="setting-value">
              <div class="ai-translations__category-input-row">
                <div class="ai-translations__category-scope-row">
                  <ComboBox
                    @value={{this.categoryScope}}
                    @content={{this.categoryScopeOptions}}
                    @onChange={{this.updateCategoryScope}}
                    @valueProperty="value"
                    @nameProperty="name"
                  />
                  {{#unless this.showCategorySelector}}
                    {{#if this.categoriesChanged}}
                      <div class="setting-controls">
                        <DButton
                          @action={{this.saveCategories}}
                          @icon="check"
                          @isLoading={{this.isSavingCategories}}
                          @ariaLabel="save"
                          class="ok setting-controls__ok"
                        />
                        <DButton
                          @action={{this.cancelCategories}}
                          @icon="xmark"
                          @isLoading={{this.isSavingCategories}}
                          @ariaLabel="cancel"
                          class="cancel setting-controls__cancel"
                        />
                      </div>
                    {{else if this.categories.length}}
                      <DButton
                        @action={{this.resetCategories}}
                        @icon="arrow-rotate-left"
                        @label="admin.settings.reset"
                        class="undo setting-controls__undo"
                      />
                    {{/if}}
                  {{/unless}}
                </div>
                {{#if this.showCategorySelector}}
                  <div class="ai-translations__category-selector-row">
                    <CategorySelector
                      @categories={{this.categories}}
                      @onChange={{this.updateCategories}}
                    />
                    {{#if this.categoriesChanged}}
                      <div class="setting-controls">
                        <DButton
                          @action={{this.saveCategories}}
                          @icon="check"
                          @isLoading={{this.isSavingCategories}}
                          @ariaLabel="save"
                          class="ok setting-controls__ok"
                        />
                        <DButton
                          @action={{this.cancelCategories}}
                          @icon="xmark"
                          @isLoading={{this.isSavingCategories}}
                          @ariaLabel="cancel"
                          class="cancel setting-controls__cancel"
                        />
                      </div>
                    {{else if this.categories.length}}
                      <DButton
                        @action={{this.resetCategories}}
                        @icon="arrow-rotate-left"
                        @label="admin.settings.reset"
                        class="undo setting-controls__undo"
                      />
                    {{/if}}
                  </div>
                {{/if}}
              </div>
              <div class="desc">{{i18n
                  "discourse_ai.translations.category_scope_description"
                }}</div>
            </div>
          </div>
        </div>
      </div>

      {{#if this.enabled}}
        <DConditionalLoadingSpinner @condition={{this.loadingProgress}}>
          {{#if this.data}}
            <AdminConfigAreaCard class="ai-translations__charts">
              <:content>
                <div class="ai-translations__progress-meta">
                  {{#if this.backfillStatusMessage}}
                    <div class="ai-translations__stat-item">
                      <span class="ai-translations__stat-label">
                        {{this.backfillStatusMessage}}
                      </span>
                    </div>
                  {{/if}}
                  {{#if this.cachedResultsNotice}}
                    <div class="ai-translations__cached-results">
                      {{dIcon "clock-rotate-left"}}
                      <span>{{this.cachedResultsNotice}}</span>
                    </div>
                  {{/if}}
                </div>
                <div class="ai-translations__chart-container">
                  <Chart
                    @chartConfig={{this.chartConfig}}
                    @loadChartDataLabelsPlugin={{true}}
                    class="ai-translations__chart"
                  />
                </div>
              </:content>
            </AdminConfigAreaCard>
          {{/if}}
        </DConditionalLoadingSpinner>
      {{/if}}

    </div>
  </template>
}
