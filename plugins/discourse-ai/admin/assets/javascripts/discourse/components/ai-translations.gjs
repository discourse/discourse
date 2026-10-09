import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import moment from "moment";
import PluginOutlet from "discourse/components/plugin-outlet";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import lazyHash from "discourse/helpers/lazy-hash";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import Category from "discourse/models/category";
import CategorySelector from "discourse/select-kit/components/category-selector";
import ComboBox from "discourse/select-kit/components/combo-box";
import MultiSelect from "discourse/select-kit/components/multi-select";
import { eq, not } from "discourse/truth-helpers";
import DAsyncContent from "discourse/ui-kit/d-async-content";
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
  @service toasts;

  @tracked overviewGeneration = 0;
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
  // Pre-checked during first-time setup so enabling translations also surfaces the switcher;
  // reflects the real setting once translations are already on.
  @tracked
  languageSwitcherRequested =
    this.siteSettings.content_localization_language_switcher !== "none" ||
    !this.translationEnabled;
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
  }

  get creditLimitReached() {
    return this.creditStatus?.hard_limit_reached === true;
  }

  get maxLocaleToast() {
    const max = this.siteSettings.content_localization_max_locales;
    return {
      duration: "short",
      data: {
        message: i18n("discourse_ai.translations.max_locales_reached", {
          max,
        }),
      },
    };
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

  get hasSavedLocales() {
    return this.originalLocales.length > 0;
  }

  get isToggleDisabled() {
    return (
      this.isTogglingTranslation ||
      !this.hasSavedLocales ||
      this.selectedLocales.length === 0
    );
  }

  get toggleDisabledReason() {
    if (this.hasSavedLocales && this.selectedLocales.length > 0) {
      return null;
    }

    return i18n(
      "discourse_ai.translations.admin_actions.enable_translations_disabled"
    );
  }

  get languageSwitcherValue() {
    return this.languageSwitcherRequested ? "all" : "none";
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

  @bind
  loadProgress() {
    return ajax("/admin/plugins/discourse-ai/ai-translations/progress.json");
  }

  @action
  navigateToLocalizationSettings() {
    this.router.transitionTo("adminConfig.localization.settings", {
      queryParams: { filter: "content_localization_supported_locales" },
    });
  }

  @action
  updateSelectedLocales(locales) {
    if (
      this.siteSettings.content_localization_max_locales &&
      locales.length > this.siteSettings.content_localization_max_locales
    ) {
      this.toasts.error(this.maxLocaleToast);
      return;
    }
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
      this.overviewGeneration += 1;

      if (expandedTargetType) {
        await this._loadTargetDetails(expandedTargetType, { retry: true });
      }
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
  async toggleLanguageSwitcher(event) {
    const previous = this.languageSwitcherRequested;
    this.languageSwitcherRequested = event.target.checked;

    // Not yet enabled: the value is applied together with the enable toggle.
    if (!this.translationEnabled) {
      return;
    }

    try {
      await ajax(
        "/admin/site_settings/content_localization_language_switcher",
        {
          type: "PUT",
          data: {
            content_localization_language_switcher: this.languageSwitcherValue,
          },
        }
      );
    } catch (e) {
      this.languageSwitcherRequested = previous;
      popupAjaxError(e);
    }
  }

  @action
  async toggleTranslationEnabled() {
    if (this.isTogglingTranslation) {
      return;
    }

    if (!this.translationEnabled && !this.hasSavedLocales) {
      return;
    }

    this.isTogglingTranslation = true;
    try {
      if (!this.translationEnabled && this.hasSavedLocales) {
        await ajax("/admin/site_settings/bulk_update", {
          type: "PUT",
          data: {
            settings: {
              content_localization_enabled: { value: true },
              content_localization_language_switcher: {
                value: this.languageSwitcherValue,
              },
              ai_translation_enabled: { value: true },
            },
          },
        });
      } else {
        await ajax("/admin/site_settings/ai_translation_enabled", {
          type: "PUT",
          data: { ai_translation_enabled: false },
        });
      }
      this.translationEnabled = !this.translationEnabled;

      if (this.translationEnabled && this.hasSavedLocales) {
        this.enabled = true;
      } else {
        this.enabled = false;
        this.expandedTargetType = null;
        this._invalidateTargetDetails();
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isTogglingTranslation = false;
    }
  }

  @bind
  backfillStatusMessage(targets) {
    if (
      this.args.model?.backfill_enabled &&
      this.args.model?.backfill_start_date &&
      this.hourlyRate > 0
    ) {
      const posts = targets?.find(({ target_type }) => target_type === "post");
      const totalRemaining = posts
        ? posts.total_count - posts.translated_count
        : 0;

      if (totalRemaining && totalRemaining > 0) {
        const formattedDate = new Date(
          this.args.model.backfill_start_date
        ).toLocaleDateString(undefined, {
          year: "numeric",
          month: "long",
          day: "numeric",
          timeZone: "UTC",
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

  @bind
  cachedResultsNotice(cachedAt) {
    if (!cachedAt) {
      return null;
    }

    return i18n("discourse_ai.translations.cached_results_notice", {
      relative_time: moment(cachedAt).fromNow(),
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

  @action
  retryTargetDetails() {
    this._loadTargetDetails(this.expandedTargetType, { retry: true });
  }

  async _loadCategories() {
    const ids = this.args.model?.category_ids || [];
    if (ids.length) {
      this.categories = await Category.asyncFindByIds(ids);
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

  <template>
    <div class="ai-translations admin-detail">
      <DPageSubheader
        @descriptionLabel={{i18n "discourse_ai.translations.description"}}
        @learnMoreUrl="https://meta.discourse.org/t/-/370969"
        @titleLabel={{i18n "discourse_ai.translations.title"}}
      >
        <:actions as |actions|>
          <actions.Default
            class="ai-translation-settings-button"
            @label="discourse_ai.translations.admin_actions.translation_settings"
            @route="adminPlugins.show.discourse-ai-features.edit"
            @routeModels={{@model.translation_id}}
          />
          <actions.Default
            class="ai-localization-settings-button"
            @label="discourse_ai.translations.admin_actions.localization_settings"
            @route="adminSiteSettingsCategory"
            @routeModels="content_localization"
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
        <div class="ai-translations__settings-fields">
          <div class="setting">
            <div class="setting-label">
              <label>{{i18n
                  "discourse_ai.translations.supported_locales"
                }}</label>
            </div>
            <div class="setting-value">
              {{#if this.siteSettings.content_localization_max_locales}}
                <div class="ai-translations__locale-info">
                  <p class="ai-translations__locale-count">
                    {{i18n
                      "discourse_ai.translations.locale_count"
                      count=this.selectedLocales.length
                      max=this.siteSettings.content_localization_max_locales
                    }}
                  </p>
                  <PluginOutlet
                    @connectorTagName="div"
                    @name="ai-translations-locale-info"
                    @outletArgs={{lazyHash
                      localesCount=this.selectedLocales.length
                      maxLocales=this.siteSettings.content_localization_max_locales
                    }}
                  />
                </div>
              {{/if}}
              <div class="ai-translations__locale-input-row">
                <MultiSelect
                  @content={{this.availableLocales}}
                  @nameProperty="name"
                  @onChange={{this.updateSelectedLocales}}
                  @options={{hash allowAny=false}}
                  @value={{this.selectedLocales}}
                  @valueProperty="value"
                />
                {{#if this.localesChanged}}
                  <div class="setting-controls">
                    <DButton
                      class="ok setting-controls__ok"
                      @action={{this.saveLocales}}
                      @ariaLabel="save"
                      @icon="check"
                      @isLoading={{this.isSavingLocales}}
                    />
                    <DButton
                      class="cancel setting-controls__cancel"
                      @action={{this.cancelLocales}}
                      @ariaLabel="cancel"
                      @icon="xmark"
                      @isLoading={{this.isSavingLocales}}
                    />
                  </div>
                {{else if this.selectedLocales.length}}
                  <DButton
                    class="btn-default undo setting-controls__undo"
                    @action={{this.resetLocales}}
                    @icon="arrow-rotate-left"
                    @label="admin.settings.reset"
                  />
                {{/if}}
              </div>
            </div>
          </div>
          <div class="setting">
            <div class="setting-label">
              <label>{{i18n "discourse_ai.translations.category_scope"}}</label>
              <div class="desc ai-translations__category-scope-desc">{{i18n
                  "discourse_ai.translations.category_scope_description"
                }}</div>
            </div>
            <div class="setting-value">
              <div class="ai-translations__category-input-row">
                <div class="ai-translations__category-scope-row">
                  <ComboBox
                    @content={{this.categoryScopeOptions}}
                    @nameProperty="name"
                    @onChange={{this.updateCategoryScope}}
                    @value={{this.categoryScope}}
                    @valueProperty="value"
                  />
                  {{#unless this.showCategorySelector}}
                    {{#if this.categoriesChanged}}
                      <div class="setting-controls">
                        <DButton
                          class="ok setting-controls__ok"
                          @action={{this.saveCategories}}
                          @ariaLabel="save"
                          @icon="check"
                          @isLoading={{this.isSavingCategories}}
                        />
                        <DButton
                          class="cancel setting-controls__cancel"
                          @action={{this.cancelCategories}}
                          @ariaLabel="cancel"
                          @icon="xmark"
                          @isLoading={{this.isSavingCategories}}
                        />
                      </div>
                    {{else if this.categories.length}}
                      <DButton
                        class="btn-default undo setting-controls__undo"
                        @action={{this.resetCategories}}
                        @icon="arrow-rotate-left"
                        @label="admin.settings.reset"
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
                          class="ok setting-controls__ok"
                          @action={{this.saveCategories}}
                          @ariaLabel="save"
                          @icon="check"
                          @isLoading={{this.isSavingCategories}}
                        />
                        <DButton
                          class="cancel setting-controls__cancel"
                          @action={{this.cancelCategories}}
                          @ariaLabel="cancel"
                          @icon="xmark"
                          @isLoading={{this.isSavingCategories}}
                        />
                      </div>
                    {{else if this.categories.length}}
                      <DButton
                        class="btn-default undo setting-controls__undo"
                        @action={{this.resetCategories}}
                        @icon="arrow-rotate-left"
                        @label="admin.settings.reset"
                      />
                    {{/if}}
                  </div>
                {{/if}}
              </div>
            </div>
          </div>
        </div>
        <div class="setting ai-translations__language-switcher">
          <label class="checkbox-label">
            <input
              checked={{this.languageSwitcherRequested}}
              disabled={{not this.hasSavedLocales}}
              type="checkbox"
              {{on "input" this.toggleLanguageSwitcher}}
            />
            <span>{{i18n
                "discourse_ai.translations.admin_actions.show_language_switcher"
              }}</span>
          </label>
          <div class="desc">{{i18n
              "discourse_ai.translations.admin_actions.show_language_switcher_description"
            }}</div>
        </div>
        <div class="setting ai-translations__toggle-container">
          {{#if this.toggleDisabledReason}}
            <DTooltip
              class="ai-translations__toggle-disabled-tooltip"
              @content={{this.toggleDisabledReason}}
            >
              <:trigger>
                <DToggleSwitch
                  disabled={{this.isToggleDisabled}}
                  @label="discourse_ai.translations.admin_actions.enable_translations"
                  @state={{this.translationEnabled}}
                  {{on "click" this.toggleTranslationEnabled}}
                />
              </:trigger>
            </DTooltip>
          {{else}}
            <DToggleSwitch
              disabled={{this.isToggleDisabled}}
              @label="discourse_ai.translations.admin_actions.enable_translations"
              @state={{this.translationEnabled}}
              {{on "click" this.toggleTranslationEnabled}}
            />
          {{/if}}
        </div>
      </div>

      {{#if this.enabled}}
        <div class="ai-translations__overview">
          <DAsyncContent
            @asyncData={{this.loadProgress}}
            @context={{this.overviewGeneration}}
            @errorMode="popup"
            @retainWhileReloading={{true}}
          >
            <:loading>
              <AiTranslationModelProgressOverviewSkeleton />
            </:loading>
            <:content as |progress|>
              <div class="ai-translations__progress-meta">
                {{#let
                  (this.backfillStatusMessage progress.targets)
                  as |backfillStatusMessage|
                }}
                  {{#if backfillStatusMessage}}
                    <div class="ai-translations__stat-item">
                      <span class="ai-translations__stat-label">
                        {{backfillStatusMessage}}
                      </span>
                    </div>
                  {{/if}}
                {{/let}}
                {{#let
                  (this.cachedResultsNotice progress.cached_at)
                  as |cachedResultsNotice|
                }}
                  {{#if cachedResultsNotice}}
                    <div class="ai-translations__cached-results">
                      {{dIcon "clock-rotate-left"}}
                      <span>{{cachedResultsNotice}}</span>
                    </div>
                  {{/if}}
                {{/let}}
              </div>

              <div
                aria-label={{i18n
                  "discourse_ai.translations.model_progress.overview_label"
                }}
                class="ai-translations__overview-grid"
              >
                {{#each progress.targets as |target|}}
                  <AiTranslationModelProgressOverviewCard
                    @expanded={{eq this.expandedTargetType target.target_type}}
                    @onToggle={{this.toggleTarget}}
                    @target={{target}}
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
                        class="btn-default"
                        @action={{this.retryTargetDetails}}
                        @icon="rotate"
                        @label="discourse_ai.translations.model_progress.detail.retry"
                      />
                    </div>
                  {{/if}}
                </div>
              {{/if}}
            </:content>
          </DAsyncContent>
        </div>
      {{/if}}

    </div>
  </template>
}
