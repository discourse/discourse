import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { getOwner } from "@ember/owner";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isNone } from "@ember/utils";
import { and } from "truth-helpers";
import DButton from "discourse/components/d-button";
import JsonSchemaEditorModal from "discourse/components/modal/json-schema-editor";
import basePath from "discourse/helpers/base-path";
import icon from "discourse/helpers/d-icon";
import { bind } from "discourse/lib/decorators";
import { deepEqual } from "discourse/lib/object";
import { sanitize } from "discourse/lib/text";
import { splitString } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import SettingValidationMessage from "admin/components/setting-validation-message";
import Description from "admin/components/site-settings/description";
import JobStatus from "admin/components/site-settings/job-status";
import SiteSetting from "admin/models/site-setting";

const CUSTOM_TYPES = [
  "bool",
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
];

export default class SiteSettingComponent extends Component {
  @service modal;
  @service router;
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

  get overridden() {
    return !this.#valuesEqual(this.setting.default, this.buffered.get("value"));
  }

  get displayDescription() {
    return this.componentType !== "bool";
  }

  get showThemeSiteSettingWarning() {
    return this.setting.themeable;
  }

  get themeSiteSettingWarningText() {
    return htmlSafe(
      i18n("admin.theme_site_settings.site_setting_warning", {
        basePath,
        defaultThemeName: sanitize(this.defaultTheme.name),
        defaultThemeId: this.defaultTheme.theme_id,
      })
    );
  }

  get dirty() {
    let bufferVal = this.buffered.get("value");
    let settingVal = this.setting?.value;

    if (isNone(bufferVal)) {
      bufferVal = "";
    }

    if (isNone(settingVal)) {
      settingVal = "";
    }

    const dirty = !this.#valuesEqual(bufferVal, settingVal);

    if (dirty) {
      this.siteSettingChangeTracker.add(this.setting);
    } else {
      this.siteSettingChangeTracker.remove(this.setting);
    }

    return dirty;
  }

  get preview() {
    const setting = this.setting;
    const value = this.buffered.get("value");
    const preview = setting.preview;
    if (preview) {
      const escapedValue = preview.replace(/\{\{value\}\}/g, value);
      return htmlSafe(`<div class="preview">${escapedValue}</div>`);
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
    return !!this.setting.isSaving;
  }

  get staffLogFilter() {
    return this.setting.staffLogFilter;
  }

  get canUpdate() {
    if (this.setting.themeable) {
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
    if (this.setting.requiresConfirmation) {
      const confirm = await this.siteSettingChangeTracker.confirmChanges(
        this.setting
      );

      if (!confirm) {
        return;
      }
    }

    if (this.setting.affectsExistingUsers) {
      await this.siteSettingChangeTracker.configureBackfill(this.setting);
    }

    await this.save();
  }

  @action
  async save() {
    try {
      this.setting.isSaving = true;

      await this._save();

      this.setting.validationMessage = null;
      this.buffered.applyChanges();

      if (this.setting.requiresReload) {
        this.siteSettingChangeTracker.refreshPage({
          [this.setting.setting]: this.setting.value,
        });
      }
    } catch (e) {
      const json = e.jqXHR?.responseJSON;
      if (json?.errors) {
        let errorString = json.errors[0];

        if (json.html_message) {
          errorString = htmlSafe(errorString);
        }

        this.setting.validationMessage = errorString;
      } else {
        // eslint-disable-next-line no-console
        console.error(e);
        this.setting.validationMessage = i18n("generic_error");
      }
    } finally {
      this.setting.isSaving = false;
    }
  }

  @action
  changeValueCallback(value) {
    this.buffered.set("value", value);
  }

  @action
  setValidationMessage(message) {
    this.setting.validationMessage = message;
  }

  @action
  cancel() {
    this.buffered.discardChanges();
    this.setting.validationMessage = null;
  }

  @action
  resetDefault() {
    this.buffered.set("value", this.setting.default);
    this.setting.validationMessage = null;
  }

  @action
  toggleSecret() {
    this.isSecret = !this.isSecret;
  }

  @action
  setDefaultValues() {
    this.buffered.set(
      "value",
      this.bufferedValues.concat(this.defaultValues).uniq().join("|")
    );
    this.setting.validationMessage = null;
  }

  _save() {
    const setting = this.buffered;
    return SiteSetting.update(setting.get("setting"), setting.get("value"), {
      updateExistingUsers: this.setting.updateExistingUsers,
    });
  }

  #valuesEqual(a, b) {
    if (
      this.setting.json_schema ||
      this.setting.schema ||
      this.setting.objects_schema
    ) {
      return deepEqual(a, b);
    } else {
      return a?.toString() === b?.toString();
    }
  }

  <template>
    <div
      data-setting={{this.setting.setting}}
      class="row setting {{this.typeClass}} {{if this.overridden 'overridden'}}"
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
                {{icon "clock-rotate-left"}}
              </span>
            </LinkTo>
          {{/if}}
        </h3>

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
            class="setting-value-edit-button"
          />

          <Description @description={{this.setting.description}} />
          <JobStatus @status={{this.status}} @progress={{this.progress}} />
        {{else}}
          <this.resolvedComponent
            {{on "keydown" this._handleKeydown}}
            @disabled={{this.setting.themeable}}
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
          {{#if this.showThemeSiteSettingWarning}}
            <div class="setting-theme-warning">
              <p class="setting-theme-warning__text">
                {{icon "paintbrush"}}
                {{this.themeSiteSettingWarningText}}
              </p>
            </div>
          {{/if}}
        {{/if}}
      </div>

      {{#if (and this.dirty this.canUpdate)}}
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
      {{else if (and this.overridden this.canUpdate)}}
        {{#if this.setting.secret}}
          <DButton
            @action={{this.toggleSecret}}
            @icon={{if this.isSecret "far-eye" "far-eye-slash"}}
            @ariaLabel="admin.settings.unmask"
            class="setting-toggle-secret"
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
