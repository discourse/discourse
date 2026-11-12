import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import moment from "moment";
import SiteSetting from "discourse/admin/models/site-setting";
import Form from "discourse/components/form";
import PluginOutlet from "discourse/components/plugin-outlet";
import SettingDefinitionField from "discourse/components/setting-definition-field";
import lazyHash from "discourse/helpers/lazy-hash";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import MultiSelect from "discourse/select-kit/components/multi-select";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  TRANSLATION_SETTING_GROUPS,
  translationSettingDefinition,
  translationSettingVisible,
} from "../lib/ai-translation-settings.js";
import { findSetting, saveSettings } from "../lib/site-settings-form.js";
import AiTranslationModelProgressDetailCard from "./ai-translation-model-progress-detail-card.gjs";
import AiTranslationModelProgressOverviewCard from "./ai-translation-model-progress-overview-card.gjs";
import AiTranslationModelProgressOverviewSkeleton from "./ai-translation-model-progress-overview-skeleton.gjs";

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
  @tracked optimisticState = null;
  @tracked formData;
  @tracked isTogglingTranslation = false;
  @tracked creditStatus = null;

  settingGroups = TRANSLATION_SETTING_GROUPS;
  targetDetailRequests = new Map();
  targetDetailGeneration = 0;
  #formApi;

  constructor() {
    super(...arguments);
    // Preserve drafts and inline errors when readiness refreshes replace the route model.
    this.formData = this.args.model.formData;
    this._checkCredits();
  }

  // Readiness is the server's call (AI enabled, a model is available, locales
  // are saved), so it is only overridden until a refresh replaces the model.
  get #optimistic() {
    return this.optimisticState?.model === this.args.model
      ? this.optimisticState
      : null;
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

  get enabled() {
    return this.#optimistic?.enabled ?? this.args.model.enabled;
  }

  get translationEnabled() {
    return (
      this.#optimistic?.translationEnabled ??
      this.args.model.translation_enabled
    );
  }

  get hasSavedLocales() {
    return Boolean(this.siteSettings.content_localization_supported_locales);
  }

  get isToggleDisabled() {
    return (
      this.isTogglingTranslation ||
      (!this.translationEnabled && !this.hasSavedLocales)
    );
  }

  get toggleDisabledReason() {
    if (!this.translationEnabled && !this.hasSavedLocales) {
      return i18n(
        "discourse_ai.translations.admin_actions.enable_translations_disabled"
      );
    }
  }

  get waitingForLanguages() {
    return this.translationEnabled && !this.hasSavedLocales;
  }

  get hiddenFromReaders() {
    return (
      this.translationEnabled &&
      this.hasSavedLocales &&
      !this.siteSettings.content_localization_enabled
    );
  }

  get hiddenFromReadersMessage() {
    return trustHTML(i18n("discourse_ai.translations.hidden_from_readers"));
  }

  get localeDefinition() {
    return translationSettingDefinition(
      this.findSetting("content_localization_supported_locales")
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
  findSetting(name) {
    return findSetting(this.args.model.settings, name);
  }

  @action
  isSettingVisible(setting, data) {
    return translationSettingVisible(this.args.model.settings, setting, data);
  }

  localeValues(value) {
    return value ? value.split("|").filter(Boolean) : [];
  }

  @action
  localeCount(value) {
    return this.localeValues(value).length;
  }

  @action
  updateLocales(field, locales) {
    const max = this.siteSettings.content_localization_max_locales;
    if (max && locales.length > max) {
      this.toasts.error(this.maxLocaleToast);
      return;
    }
    field.set(locales.join("|"));
  }

  @action
  registerFormApi(api) {
    this.#formApi = api;
  }

  @action
  async save(data) {
    const settings = this.args.model.settings;
    const success = await saveSettings(
      settings,
      data,
      this.#formApi,
      (key, value) => {
        if (key in this.siteSettings) {
          this.siteSettings[key] = value;
        }
      },
      { isVisible: (setting) => this.isSettingVisible(setting, data) }
    );

    if (success) {
      this.toasts.success({
        data: { message: i18n("saved") },
        duration: "short",
      });
    } else {
      this.toasts.error({
        data: {
          message: i18n("discourse_ai.translations.settings_save_error"),
        },
        duration: "long",
      });
    }

    // Some settings save even when others fail.
    await this.#refreshModel();

    const expandedTargetType = this.expandedTargetType;
    this._invalidateTargetDetails({ keepDisplayed: this.enabled });
    this.overviewGeneration += 1;
    if (expandedTargetType) {
      await this._loadTargetDetails(expandedTargetType, { retry: true });
    }
  }

  @action
  async toggleTranslationEnabled() {
    if (this.isToggleDisabled) {
      return;
    }

    this.isTogglingTranslation = true;
    try {
      const value = !this.translationEnabled;
      await SiteSetting.update("ai_translation_enabled", value);
      this.siteSettings.ai_translation_enabled = value;
      // Readiness stays false until the server confirms it for the new value.
      this.optimisticState = {
        model: this.args.model,
        translationEnabled: value,
        enabled: false,
      };
      this.overviewGeneration += 1;
      if (!value) {
        this.expandedTargetType = null;
        this._invalidateTargetDetails();
      }
      await this.#refreshModel();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isTogglingTranslation = false;
    }
  }

  @bind
  backfillStatusMessage(targets) {
    const { backfill_enabled, backfill_start_date } = this.args.model;

    if (!backfill_enabled) {
      return i18n("discourse_ai.translations.stats.backfill_disabled");
    }

    const posts = targets?.find(({ target_type }) => target_type === "post");
    const totalRemaining = posts
      ? posts.total_count - posts.translated_count
      : 0;

    if (!backfill_start_date || totalRemaining <= 0) {
      return null;
    }

    const formattedDate = new Date(backfill_start_date).toLocaleDateString(
      undefined,
      {
        year: "numeric",
        month: "long",
        day: "numeric",
        timeZone: "UTC",
      }
    );

    return trustHTML(
      i18n("discourse_ai.translations.stats.backfill_message", {
        date: formattedDate,
        settingsUrl: "#ai-translations-backfill",
      })
    );
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

  async #refreshModel() {
    const previousData = this.args.model.formData;
    try {
      await this.router.refresh();
      for (const [name, value] of Object.entries(this.args.model.formData)) {
        if (
          value !== previousData[name] &&
          this.#formApi?.get(name) === previousData[name]
        ) {
          await this.#formApi.set(name, value);
          this.#formApi.commitField(name);
        }
      }
    } catch {
      // The settings were saved; a failed refresh only leaves stale readiness.
    }
  }

  async _checkCredits() {
    try {
      this.creditStatus =
        await this.aiCredits.getFeatureCreditStatus("locale_detector");
    } catch {
      this.creditStatus = null;
    }
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
          <actions.Wrapped>
            <div class="ai-translations__toggle-container">
              <DToggleSwitch
                aria-describedby={{if
                  this.toggleDisabledReason
                  "ai-translations-toggle-hint"
                }}
                disabled={{this.isToggleDisabled}}
                @label="discourse_ai.translations.admin_actions.enabled"
                @state={{this.translationEnabled}}
                {{on "click" this.toggleTranslationEnabled}}
              />
            </div>
          </actions.Wrapped>
        </:actions>
      </DPageSubheader>

      {{#if this.creditLimitReached}}
        <div class="alert alert-warning ai-translations__credit-warning">
          {{dIcon "triangle-exclamation"}}
          <span>{{this.creditLimitWarningMessage}}</span>
        </div>
      {{/if}}

      {{#if this.toggleDisabledReason}}
        <p
          class="ai-translations__toggle-hint"
          id="ai-translations-toggle-hint"
        >
          {{this.toggleDisabledReason}}
        </p>
      {{/if}}

      {{#if this.waitingForLanguages}}
        <div class="alert alert-warning ai-translations__languages-notice">
          {{i18n "discourse_ai.translations.waiting_for_languages"}}
        </div>
      {{/if}}

      {{#if this.hiddenFromReaders}}
        <div class="alert alert-info ai-translations__readers-notice">
          {{this.hiddenFromReadersMessage}}
        </div>
      {{/if}}

      <Form
        class="ai-translations__settings-panel"
        @data={{this.formData}}
        @onRegisterApi={{this.registerFormApi}}
        @onSubmit={{this.save}}
        as |form data|
      >
        <form.Section
          @title={{i18n "discourse_ai.translations.sections.languages"}}
        >
          <form.Field
            class="ai-translations__locales"
            @description={{this.localeDefinition.description}}
            @format="large"
            @labelFormat="full"
            @name="content_localization_supported_locales"
            @title={{this.localeDefinition.label}}
            @type="custom"
            as |field|
          >
            <field.Control>
              <MultiSelect
                @content={{this.siteSettings.available_locales}}
                @nameProperty="name"
                @onChange={{fn this.updateLocales field}}
                @options={{hash allowAny=false}}
                @value={{this.localeValues field.value}}
                @valueProperty="value"
              />
            </field.Control>
          </form.Field>
          <div class="ai-translations__locale-info">
            {{#if this.siteSettings.content_localization_max_locales}}
              <p class="ai-translations__locale-count">
                {{i18n
                  "discourse_ai.translations.locale_count"
                  count=(this.localeCount
                    data.content_localization_supported_locales
                  )
                  max=this.siteSettings.content_localization_max_locales
                }}
              </p>
            {{/if}}
            <PluginOutlet
              @connectorTagName="div"
              @name="ai-translations-locale-info"
              @outletArgs={{lazyHash
                localesCount=(this.localeCount
                  data.content_localization_supported_locales
                )
                maxLocales=this.siteSettings.content_localization_max_locales
              }}
            />
          </div>
        </form.Section>
        {{#each this.settingGroups as |group|}}
          {{#unless (eq group.key "languages")}}
            {{#if (eq group.key "agents")}}
              <details class="ai-translations__agents">
                <summary>{{i18n
                    "discourse_ai.translations.sections.agents"
                  }}</summary>
                <form.Section>
                  {{#each group.settings as |name|}}
                    {{#let (this.findSetting name) as |setting|}}
                      {{#if (this.isSettingVisible setting data)}}
                        <SettingDefinitionField
                          @definition={{translationSettingDefinition setting}}
                          @disabled={{setting.disabled}}
                          @form={{form}}
                        />
                      {{/if}}
                    {{/let}}
                  {{/each}}
                </form.Section>
              </details>
            {{else}}
              <form.Section
                id={{concat "ai-translations-" group.key}}
                @title={{i18n
                  (concat "discourse_ai.translations.sections." group.key)
                }}
              >
                {{#each group.settings as |name|}}
                  {{#let (this.findSetting name) as |setting|}}
                    {{#if (this.isSettingVisible setting data)}}
                      <SettingDefinitionField
                        @definition={{translationSettingDefinition setting}}
                        @disabled={{setting.disabled}}
                        @form={{form}}
                      />
                    {{/if}}
                  {{/let}}
                {{/each}}
                {{#if (eq group.key "readers")}}
                  <LinkTo
                    class="ai-translations__more-settings"
                    @route="adminConfig.localization.settings"
                  >
                    {{i18n "discourse_ai.translations.more_language_settings"}}
                  </LinkTo>
                {{/if}}
              </form.Section>
            {{/if}}
          {{/unless}}
        {{/each}}
        <form.Actions><form.Submit @label="save" /></form.Actions>
      </Form>

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
