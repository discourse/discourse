/* eslint-disable ember/no-side-effects */
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { getOwner } from "@ember/owner";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { isNone } from "@ember/utils";
import SettingValidationMessage from "discourse/admin/components/setting-validation-message";
import Description from "discourse/admin/components/site-settings/description";
import JobStatus from "discourse/admin/components/site-settings/job-status";
import SiteSetting, {
  isSettingValueTrue,
} from "discourse/admin/models/site-setting";
import JsonSchemaEditorModal from "discourse/components/modal/json-schema-editor";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import { bind } from "discourse/lib/decorators";
import { deepEqual } from "discourse/lib/object";
import { sanitize } from "discourse/lib/text";
import { splitString } from "discourse/lib/utilities";
import { and, not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dBasePath from "discourse/ui-kit/helpers/d-base-path";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const CUSTOM_TYPES = [
  "bool",
  "datetime",
  "integer",
  "enum",
  "list",
  "url_list",
  "host_list",
  "category_list",
  "value_list",
  "category",
  "uploaded_image_list",
  "compact_list",
  "secret_list",
  "upload",
  "group_list",
  "group",
  "tag_list",
  "tag_group_list",
  "color",
  "simple_list",
  "emoji_list",
  "named_list",
  "file_size_restriction",
  "file_types_list",
  "font_list",
  "locale_list",
  "locale_enum",
  "topic",
  "icon",
];

export default class SiteSettingComponent extends Component {
  @service modal;
  @service router;
  @service adminSiteSettingStore;
  @service siteSettingChangeTracker;
  @service messageBus;
  @service site;

  @tracked isSecret = null;
  @tracked status = null;
  @tracked progress = null;
  updateExistingUsers = null;

  constructor() {
    super(...arguments);
    this.isSecret = this.setting?.secret;

    if (this.canSubscribeToSettingsJobs) {
      this.messageBus.subscribe(
        `/site_setting/${this.setting.setting}/process`,
        this.onMessage
      );
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);

    if (this.canSubscribeToSettingsJobs) {
      this.messageBus.unsubscribe(
        `/site_setting/${this.setting.setting}/process`,
        this.onMessage
      );
    }
  }

  canSubscribeToSettingsJobs() {
    const settingName = this.setting.setting;
    return (
      settingName.includes("default_categories") ||
      settingName.includes("default_tags")
    );
  }

  get defaultTheme() {
    return this.site.user_themes.find((theme) => theme.default);
  }

  @bind
  async onMessage(membership) {
    this.status = membership.status;
    this.progress = membership.progress;
  }

  @action
  async _handleKeydown(event) {
    if (
      event.key === "Enter" &&
      event.target.classList.contains("input-setting-string")
    ) {
      await this.save();
    }
  }

  get resolvedComponent() {
    return getOwner(this).resolveRegistration(
      `component:${this.componentName}`
    );
  }

  @dependentKeyCompat
  get buffered() {
    return this.setting.buffered;
  }

  get componentName() {
    return `site-settings/${this.typeClass}`;
  }

  get siteSettingComponent() {
    return getOwner(this).resolveRegistration("component:site-setting");
  }

  get overridden() {
    return this.settingIsOverridden(this.setting);
  }

  get groupedOverridden() {
    return [this.setting, ...this.inlineDependentSettings].some((setting) =>
      this.settingIsOverridden(setting)
    );
  }

  settingIsOverridden(setting) {
    return !this.#valuesEqual(
      setting.default,
      setting.buffered.get("value"),
      setting
    );
  }

  get displayDescription() {
    return this.componentType !== "bool";
  }

  get showThemeSiteSettingWarning() {
    return this.setting.themeable;
  }

  get showUpcomingChangeDefaultWarning() {
    return this.setting.upcoming_change_default_override_metadata;
  }

  get showDependsOnNotice() {
    return this.setting.depends_on?.length > 0;
  }

  get dependsOnNoticeText() {
    const path = dBasePath();
    const links = this.setting.depends_on
      .map((name, index) => {
        const label = sanitize(
          this.setting.depends_on_humanized_names?.[index] ||
            name.replaceAll("_", " ")
        );
        return `<a href="${path}/admin/site_settings/category/all_results?filter=${encodeURIComponent(name)}">${label}</a>`;
      })
      .join(", ");
    const translationKey =
      Object.keys(this.setting.depends_on_values ?? {}).length > 0
        ? "admin.site_settings.depends_on_values_notice"
        : "admin.site_settings.depends_on_notice";

    return trustHTML(
      i18n(translationKey, {
        count: this.setting.depends_on.length,
        dependencyLinks: links,
      })
    );
  }

  get themeSiteSettingWarningText() {
    return trustHTML(
      i18n("admin.theme_site_settings.site_setting_warning", {
        basePath: dBasePath,
        defaultThemeName: sanitize(this.defaultTheme.name),
        defaultThemeId: this.defaultTheme.theme_id,
      })
    );
  }

  get upcomingChangeDefaultWarningText() {
    // We only want to show the changed value for basic setting
    // types otherwise the warning might get too long (e.g. strings)
    // or hard to represent (e.g. upload, tag group list etc.)
    if (
      [
        "icon",
        "enum",
        "email",
        "username",
        "bool",
        "integer",
        "float",
      ].includes(this.setting.type)
    ) {
      return trustHTML(
        i18n("admin.upcoming_changes.default_warning", {
          basePath: dBasePath,
          changeNamesFilter:
            this.setting.upcoming_change_default_override_metadata
              .change_setting_name,
          oldDefaultValue:
            this.setting.upcoming_change_default_override_metadata.old_default,
          newDefaultValue:
            this.setting.upcoming_change_default_override_metadata.new_default,
        })
      );
    }

    return trustHTML(
      i18n("admin.upcoming_changes.default_warning_short", {
        basePath: dBasePath,
        changeNamesFilter:
          this.setting.upcoming_change_default_override_metadata
            .change_setting_name,
      })
    );
  }

  get dirty() {
    return this.settingIsDirty(this.setting);
  }

  get groupedDirty() {
    return this.dirtySettings.length > 0;
  }

  get dirtySettings() {
    return [this.setting, ...this.inlineDependentSettings].filter((setting) =>
      this.settingIsDirty(setting)
    );
  }

  settingIsDirty(setting) {
    let bufferVal = this.buffered.get("value");
    let settingVal = setting?.value;

    if (setting !== this.setting) {
      bufferVal = setting.buffered.get("value");
    }

    if (isNone(bufferVal)) {
      bufferVal = "";
    }

    if (isNone(settingVal)) {
      settingVal = "";
    }

    const dirty = !this.#valuesEqual(bufferVal, settingVal, setting);

    if (dirty) {
      this.siteSettingChangeTracker.add(setting);
    } else {
      this.siteSettingChangeTracker.remove(setting);
    }

    return dirty;
  }

  get preview() {
    const setting = this.setting;
    const value = this.buffered.get("value");
    const preview = setting.preview;
    if (preview) {
      const escapedValue = preview.replace(/\{\{value\}\}/g, value);
      return trustHTML(`<div class="preview">${escapedValue}</div>`);
    }
    return null;
  }

  get typeClass() {
    const componentType = this.componentType;
    return componentType.replace(/\_/g, "-");
  }

  get setting() {
    return this.args.setting;
  }

  get inlineDependentSettings() {
    if (this.args.inline) {
      return [];
    }

    return this.adminSiteSettingStore.inlineDependentSettings(this.setting);
  }

  get settingName() {
    return this.setting.label || this.setting.humanized_name;
  }

  get componentType() {
    const type = this.type;
    return CUSTOM_TYPES.includes(type) ? type : "string";
  }

  get type() {
    const setting = this.setting;
    if (setting.type === "list" && setting.list_type) {
      return `${setting.list_type}_list`;
    }
    return setting.type;
  }

  get allowAny() {
    const anyValue = this.setting?.anyValue;
    return anyValue !== false;
  }

  get bufferedValues() {
    const value = this.buffered.get("value");
    return splitString(value, "|");
  }

  get defaultValues() {
    const value = this.setting?.defaultValues;
    return splitString(value, "|");
  }

  get defaultIsAvailable() {
    const defaultValues = this.defaultValues;
    const bufferedValues = this.bufferedValues;
    return (
      defaultValues.length > 0 &&
      !defaultValues.every((value) => bufferedValues.includes(value))
    );
  }

  get settingEditButton() {
    const setting = this.setting;
    if (setting.json_schema) {
      return {
        action: () => {
          this.modal.show(JsonSchemaEditorModal, {
            model: {
              updateValue: (value) => {
                this.buffered.set("value", value);
              },
              value: this.buffered.get("value"),
              settingName: setting.setting,
              jsonSchema: setting.json_schema,
            },
          });
        },
        label: "admin.site_settings.json_schema.edit",
        icon: "pencil",
      };
    } else if (setting.schema) {
      return {
        action: () => {
          this.router.transitionTo("admin.schema", setting.setting);
        },
        label: "admin.site_settings.json_schema.edit",
        icon: "pencil",
      };
    } else if (setting.objects_schema) {
      return {
        action: () => {
          this.router.transitionTo(
            "adminCustomizeThemes.show.schema",
            setting.setting
          );
        },
        label: "admin.customize.theme.edit_objects_theme_setting",
        icon: "pencil",
      };
    }
    return null;
  }

  get disableControls() {
    return [this.setting, ...this.inlineDependentSettings].some(
      (setting) => setting.isSaving
    );
  }

  get staffLogFilter() {
    return this.setting.staffLogFilter;
  }

  get isDisabled() {
    return (
      this.setting.themeable ||
      this.setting.disabled ||
      this.isDisabledByDependency
    );
  }

  get isDisabledByDependency() {
    if (this.setting.depends_behavior !== "hidden") {
      return false;
    }
    return !this.adminSiteSettingStore.dependenciesSatisfied(this.setting);
  }

  get canUpdate() {
    if (this.isDisabled) {
      return false;
    }

    if (!this.status || this.status === "completed") {
      return true;
    } else {
      return false;
    }
  }

  @action
  async update() {
    const dirtySettings = this.dirtySettings;

    for (const setting of dirtySettings) {
      if (!setting.requiresConfirmation) {
        continue;
      }

      const confirm =
        await this.siteSettingChangeTracker.confirmChanges(setting);

      if (!confirm) {
        return;
      }
    }

    for (const setting of dirtySettings) {
      if (setting.affectsExistingUsers) {
        await this.siteSettingChangeTracker.configureBackfill(setting);
      }
    }

    await this.save(dirtySettings);
  }

  @action
  async save(settings = [this.setting]) {
    settings.forEach((setting) => (setting.isSaving = true));

    try {
      await this._save(settings);

      const refreshParams = {};
      settings.forEach((setting) => {
        setting.validationMessage = null;
        setting.buffered.applyChanges();

        if (setting.requiresReload) {
          refreshParams[setting.setting] = setting.value;
        }
      });

      if (Object.keys(refreshParams).length > 0) {
        this.siteSettingChangeTracker.refreshPage(refreshParams);
      }
    } catch (e) {
      const json = e.jqXHR?.responseJSON;
      if (json?.errors) {
        let errorString = json.errors[0];

        if (json.html_message) {
          errorString = trustHTML(sanitize(errorString));
          settings.forEach((setting) => setting.buffered.discardChanges());
        }

        settings.forEach(
          (setting) => (setting.validationMessage = errorString)
        );
      } else {
        // eslint-disable-next-line no-console
        console.error(e);
        settings.forEach(
          (setting) => (setting.validationMessage = i18n("generic_error"))
        );
      }
    } finally {
      settings.forEach((setting) => (setting.isSaving = false));
    }
  }

  @action
  changeValueCallback(value) {
    this.buffered.set("value", value);
    if (isSettingValueTrue(value)) {
      this.adminSiteSettingStore.reveal(this.setting.setting);
    }
  }

  @action
  setValidationMessage(message) {
    this.setting.validationMessage = message;
  }

  @action
  cancel() {
    this.dirtySettings.forEach((setting) => {
      setting.buffered.discardChanges();
      setting.validationMessage = null;
    });
  }

  @action
  resetDefault() {
    [this.setting, ...this.inlineDependentSettings].forEach((setting) => {
      if (!this.settingIsOverridden(setting)) {
        return;
      }

      setting.buffered.set("value", setting.default);
      setting.validationMessage = null;
      if (isSettingValueTrue(setting.default)) {
        this.adminSiteSettingStore.reveal(setting.setting);
      }
    });
  }

  @action
  toggleSecret() {
    this.isSecret = !this.isSecret;
  }

  @action
  setDefaultValues() {
    this.buffered.set(
      "value",
      uniqueItemsFromArray(this.bufferedValues.concat(this.defaultValues)).join(
        "|"
      )
    );
    this.setting.validationMessage = null;
  }

  _save(settings) {
    if (settings.length === 1) {
      const setting = settings[0].buffered;
      return SiteSetting.update(setting.get("setting"), setting.get("value"), {
        updateExistingUsers: settings[0].updateExistingUsers,
      });
    }

    const params = {};
    settings.forEach((setting) => {
      params[setting.buffered.get("setting")] = {
        value: setting.buffered.get("value"),
        backfill: !!setting.updateExistingUsers,
      };
    });

    return SiteSetting.bulkUpdate(params);
  }

  #valuesEqual(a, b, setting = this.setting) {
    if (setting.json_schema || setting.schema || setting.objects_schema) {
      return deepEqual(a, b);
    } else {
      return a?.toString() === b?.toString();
    }
  }

  <template>
    <div
      data-setting={{this.setting.setting}}
      class="row setting
        {{this.typeClass}}
        {{if this.overridden 'overridden'}}
        {{if this.isDisabled 'disabled'}}
        {{if this.isDisabledByDependency 'disabled-by-dependency'}}
        {{if @inline 'inline-dependent-setting'}}"
      ...attributes
    >
      <div class="setting-label">
        <h3>
          {{this.settingName}}

          {{#if this.staffLogFilter}}
            <LinkTo
              @route="adminLogs.staffActionLogs"
              @query={{hash filters=this.staffLogFilter force_refresh=true}}
              class="staff-action-log-link"
              title={{i18n "admin.settings.history"}}
            >
              <span class="history-icon">
                {{dIcon "clock-rotate-left"}}
              </span>
            </LinkTo>
          {{/if}}
        </h3>

        <PluginOutlet
          @name="site-setting-after-label"
          @outletArgs={{lazyHash setting=this.setting}}
        />

        {{#if this.defaultIsAvailable}}
          <DButton
            class="btn-link"
            @action={{this.setDefaultValues}}
            @translatedLabel={{this.setting.setDefaultValuesLabel}}
          />
        {{/if}}
      </div>

      <div class="setting-value">
        {{#if this.settingEditButton}}
          <DButton
            @action={{this.settingEditButton.action}}
            @icon={{this.settingEditButton.icon}}
            @label={{this.settingEditButton.label}}
            class="btn-default setting-value-edit-button"
          />

          <Description @description={{this.setting.description}} />
          <JobStatus @status={{this.status}} @progress={{this.progress}} />
        {{else}}
          <this.resolvedComponent
            {{on "keydown" this._handleKeydown}}
            @disabled={{this.isDisabled}}
            @setting={{this.setting}}
            @value={{this.buffered.value}}
            @preview={{this.preview}}
            @isSecret={{this.isSecret}}
            @allowAny={{this.allowAny}}
            @changeValueCallback={{this.changeValueCallback}}
            @setValidationMessage={{this.setValidationMessage}}
          />
          <SettingValidationMessage
            @message={{this.setting.validationMessage}}
          />
          {{#if this.displayDescription}}
            <Description @description={{this.setting.description}} />
            <JobStatus @status={{this.status}} @progress={{this.progress}} />
          {{/if}}
          {{#if this.inlineDependentSettings.length}}
            <div class="inline-dependent-settings">
              {{#each this.inlineDependentSettings as |dependentSetting|}}
                <this.siteSettingComponent
                  @setting={{dependentSetting}}
                  @inline={{true}}
                />
              {{/each}}
            </div>
          {{/if}}
          <PluginOutlet
            @name="site-setting-after-description"
            @outletArgs={{lazyHash setting=this.setting}}
          />
          {{#if this.showThemeSiteSettingWarning}}
            <div class="setting-override-warning setting-theme-warning">
              <p class="setting-theme-warning__text">
                {{dIcon "paintbrush"}}
                {{this.themeSiteSettingWarningText}}
              </p>
            </div>
          {{/if}}
          {{#if this.showUpcomingChangeDefaultWarning}}
            <div
              class="setting-override-warning setting-upcoming-change-warning"
            >
              <p class="setting-upcoming-change-warning__text">
                {{dIcon "flask"}}
                {{this.upcomingChangeDefaultWarningText}}
              </p>
            </div>
          {{/if}}
          {{#if this.showDependsOnNotice}}
            <div class="setting-override-warning setting-depends-on-notice">
              <p class="setting-depends-on-notice__text">
                {{dIcon "link"}}
                {{this.dependsOnNoticeText}}
              </p>
            </div>
          {{/if}}
        {{/if}}
      </div>

      {{#if (and this.groupedDirty this.canUpdate (not @inline))}}
        <div class="setting-controls">
          <DButton
            @action={{this.update}}
            @icon="check"
            @isLoading={{this.disableControls}}
            @ariaLabel="admin.settings.save"
            class="ok setting-controls__ok"
          />
          <DButton
            @action={{this.cancel}}
            @icon="xmark"
            @isLoading={{this.disableControls}}
            @ariaLabel="admin.settings.cancel"
            class="cancel setting-controls__cancel"
          />
        </div>
      {{else if (and this.groupedOverridden this.canUpdate (not @inline))}}
        {{#if this.setting.secret}}
          <DButton
            @action={{this.toggleSecret}}
            @icon={{if this.isSecret "far-eye" "far-eye-slash"}}
            @ariaLabel="admin.settings.unmask"
            class="btn-default setting-toggle-secret"
          />
        {{/if}}

        <DButton
          class="btn-default undo setting-controls__undo"
          @action={{this.resetDefault}}
          @icon="arrow-rotate-left"
          @label="admin.settings.reset"
        />
      {{/if}}
    </div>
  </template>
}
