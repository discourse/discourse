import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import moment from "moment";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Category from "discourse/models/category";
import CategorySelector from "discourse/select-kit/components/category-selector";
import ComboBox from "discourse/select-kit/components/combo-box";
import MultiSelect from "discourse/select-kit/components/multi-select";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AiTranslationModelProgressDetailCard from "./ai-translation-model-progress-detail-card";
import AiTranslationModelProgressOverviewCard from "./ai-translation-model-progress-overview-card";
import AiTranslationModelProgressOverviewSkeleton from "./ai-translation-model-progress-overview-skeleton";

export default class AiTranslations extends Component {
  @service aiCredits;
  @service router;
  @service siteSettings;

  @tracked targets = null;
  @tracked loadingProgress = false;
  @tracked progressCachedAt = null;
  @tracked expandedTargetType = null;
  @tracked targetDetails = {};
  @tracked loadingTargetDetails = {};
  @tracked targetDetailErrors = {};
  @tracked displayedTargetDetails = null;
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
  targetDetailRequests = new Map();
  targetDetailGeneration = 0;

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

  async _loadProgress({ showLoading = true } = {}) {
    if (showLoading) {
      this.loadingProgress = true;
    }

    try {
      const response = await ajax(
        "/admin/plugins/discourse-ai/ai-translations/progress.json"
      );
      this.targets = response.targets;
      this.progressCachedAt = response.cached_at;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      if (showLoading) {
        this.loadingProgress = false;
      }
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

      const expandedTargetType = this.expandedTargetType;
      this._invalidateTargetDetails({ keepDisplayed: true });

      const refreshes = [this._loadProgress({ showLoading: false })];
      if (expandedTargetType) {
        refreshes.push(
          this._loadTargetDetails(expandedTargetType, { retry: true })
        );
      }
      await Promise.all(refreshes);
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
        this.targets = null;
        this.progressCachedAt = null;
        this.expandedTargetType = null;
        this._invalidateTargetDetails();
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isTogglingTranslation = false;
    }
  }

  get backfillStatusMessage() {
    if (
      this.args.model?.backfill_enabled &&
      this.args.model?.backfill_max_age_days &&
      this.hourlyRate > 0
    ) {
      const posts = this.targets?.find(
        ({ target_type }) => target_type === "post"
      );
      const totalRemaining = posts
        ? posts.total_count - posts.translated_count
        : 0;

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

  @action
  toggleTarget(targetType) {
    if (this.expandedTargetType === targetType) {
      this.expandedTargetType = null;
      this.displayedTargetDetails = null;
      return;
    }

    this.expandedTargetType = targetType;
    this._loadTargetDetails(targetType);
  }

  async _loadTargetDetails(targetType, { retry = false } = {}) {
    if (this.targetDetails[targetType] && !retry) {
      this.displayedTargetDetails = this.targetDetails[targetType];
      return;
    }

    const generation = this.targetDetailGeneration;
    let request = this.targetDetailRequests.get(targetType);
    if (!request || retry) {
      request = ajax(
        `/admin/plugins/discourse-ai/ai-translations/progress/${targetType}.json`
      );
      this.targetDetailRequests.set(targetType, request);
    }

    this.loadingTargetDetails = {
      ...this.loadingTargetDetails,
      [targetType]: true,
    };
    this.targetDetailErrors = {
      ...this.targetDetailErrors,
      [targetType]: false,
    };

    try {
      const response = await request;
      if (generation === this.targetDetailGeneration && this.enabled) {
        this.targetDetails = {
          ...this.targetDetails,
          [targetType]: response,
        };
        if (this.expandedTargetType === targetType) {
          this.displayedTargetDetails = response;
        }
      }
    } catch {
      if (generation === this.targetDetailGeneration && this.enabled) {
        this.targetDetailErrors = {
          ...this.targetDetailErrors,
          [targetType]: true,
        };
      }
    } finally {
      if (generation === this.targetDetailGeneration) {
        if (this.targetDetailRequests.get(targetType) === request) {
          this.targetDetailRequests.delete(targetType);
        }
        this.loadingTargetDetails = {
          ...this.loadingTargetDetails,
          [targetType]: false,
        };
      }
    }
  }

  _invalidateTargetDetails({ keepDisplayed = false } = {}) {
    this.targetDetailGeneration += 1;
    this.targetDetails = {};
    this.loadingTargetDetails = {};
    this.targetDetailErrors = {};
    this.targetDetailRequests.clear();

    if (!keepDisplayed) {
      this.displayedTargetDetails = null;
    }
  }

  get isLoadingExpandedTargetDetails() {
    return this.loadingTargetDetails[this.expandedTargetType];
  }

  get hasExpandedTargetDetailError() {
    return this.targetDetailErrors[this.expandedTargetType];
  }

  get isDetailStateOverlay() {
    return Boolean(
      this.displayedTargetDetails &&
      (this.isLoadingExpandedTargetDetails || this.hasExpandedTargetDetailError)
    );
  }

  get expandedTargetTitle() {
    if (!this.expandedTargetType) {
      return null;
    }

    return i18n(
      `discourse_ai.translations.model_progress.targets.${this.expandedTargetType}.title`
    );
  }

  @action
  retryTargetDetails() {
    this._loadTargetDetails(this.expandedTargetType, { retry: true });
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
                    class="btn-default undo setting-controls__undo"
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
                        class="btn-default undo setting-controls__undo"
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
                        class="btn-default undo setting-controls__undo"
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
        <div class="ai-translations__overview">
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

          {{#if this.loadingProgress}}
            <AiTranslationModelProgressOverviewSkeleton />
          {{else if this.targets}}
            <div
              class="ai-translations__overview-grid"
              aria-label={{i18n
                "discourse_ai.translations.model_progress.overview_label"
              }}
            >
              {{#each this.targets as |target|}}
                <AiTranslationModelProgressOverviewCard
                  @target={{target}}
                  @expanded={{eq this.expandedTargetType target.target_type}}
                  @onToggle={{this.toggleTarget}}
                />
              {{/each}}
            </div>
            {{#if this.expandedTargetType}}
              <div class="ai-translation-model-progress-detail-region">
                {{#if this.displayedTargetDetails}}
                  <div aria-hidden={{this.isDetailStateOverlay}}>
                    <AiTranslationModelProgressDetailCard
                      @data={{this.displayedTargetDetails}}
                    />
                  </div>
                {{/if}}
                {{#if this.isLoadingExpandedTargetDetails}}
                  <div
                    class="ai-translation-model-progress-detail-state
                      {{if this.isDetailStateOverlay '--overlay'}}"
                    role="status"
                  >
                    {{i18n
                      "discourse_ai.translations.model_progress.detail.loading"
                      target=this.expandedTargetTitle
                    }}
                  </div>
                {{else if this.hasExpandedTargetDetailError}}
                  <div
                    class="ai-translation-model-progress-detail-state --error
                      {{if this.isDetailStateOverlay '--overlay'}}"
                    role="alert"
                  >
                    <span>
                      {{i18n
                        "discourse_ai.translations.model_progress.detail.load_error"
                        target=this.expandedTargetTitle
                      }}
                    </span>
                    <DButton
                      @action={{this.retryTargetDetails}}
                      @icon="rotate"
                      @label="discourse_ai.translations.model_progress.detail.retry"
                      class="btn-default"
                    />
                  </div>
                {{/if}}
              </div>
            {{/if}}
          {{/if}}
        </div>
      {{/if}}

    </div>
  </template>
}
