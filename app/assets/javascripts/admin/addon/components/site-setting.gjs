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
import DButton from "discourse/components/d-button";
import JsonSchemaEditorModal from "discourse/components/modal/json-schema-editor";
import icon from "discourse/helpers/d-icon";
import { deepEqual } from "discourse/lib/object";
import { humanizedSettingName } from "discourse/lib/site-settings-utils";
import { splitString } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import SettingValidationMessage from "admin/components/setting-validation-message";
import Description from "admin/components/site-settings/description";
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
];

export default class SiteSettingComponent extends Component {
  @service modal;
  @service router;
  @service dialog;
  @service siteSettingChangeTracker;

  @tracked isSecret = null;
  updateExistingUsers = null;

  constructor() {
    super(...arguments);
    this.isSecret = this.args.setting?.secret;
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
    return this.args.setting.buffered;
  }

  get componentName() {
    return `site-settings/${this.typeClass}`;
  }

  get overridden() {
    return this.args.setting.default !== this.buffered.get("value");
  }

  get displayDescription() {
    return this.componentType !== "bool";
  }

  get dirty() {
    let bufferVal = this.buffered.get("value");
    let settingVal = this.args.setting?.value;

    if (isNone(bufferVal)) {
      bufferVal = "";
    }

    if (isNone(settingVal)) {
      settingVal = "";
    }

    const dirty = !deepEqual(bufferVal, settingVal);

    if (dirty) {
      this.siteSettingChangeTracker.add(this.args.setting);
    } else {
      this.siteSettingChangeTracker.remove(this.args.setting);
    }

    return dirty;
  }

  get preview() {
    const setting = this.args.setting;
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

  get settingName() {
    const setting = this.args.setting;
    return humanizedSettingName(setting.setting, setting.label);
  }

  get componentType() {
    const type = this.type;
    return CUSTOM_TYPES.includes(type) ? type : "string";
  }

  get type() {
    const setting = this.args.setting;
    if (setting.type === "list" && setting.list_type) {
      return `${setting.list_type}_list`;
    }
    return setting.type;
  }

  get allowAny() {
    const anyValue = this.args.setting?.anyValue;
    return anyValue !== false;
  }

  get bufferedValues() {
    const value = this.buffered.get("value");
    return splitString(value, "|");
  }

  get defaultValues() {
    const value = this.args.setting?.defaultValues;
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
    const setting = this.args.setting;
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
    return !!this.args.setting.isSaving;
  }

  get staffLogFilter() {
    return this.args.setting.staffLogFilter;
  }

  @action
  async update() {
    if (this.args.setting.requiresConfirmation) {
      const confirm = await this.siteSettingChangeTracker.confirmChanges(
        this.args.setting
      );

      if (!confirm) {
        return;
      }
    }

    if (this.args.setting.affectsExistingUsers) {
      await this.siteSettingChangeTracker.configureBackfill(this.args.setting);
    }

    await this.save();
  }

  @action
  async save() {
    try {
      this.args.setting.isSaving = true;

      await this._save();

      this.args.setting.validationMessage = null;
      this.buffered.applyChanges();

      if (this.args.setting.requiresReload) {
        this.siteSettingChangeTracker.refreshPage({
          [this.args.setting.setting]: this.args.setting.value,
        });
      }
    } catch (e) {
      const json = e.jqXHR?.responseJSON;
      if (json?.errors) {
        let errorString = json.errors[0];

        if (json.html_message) {
          errorString = htmlSafe(errorString);
        }

        this.args.setting.validationMessage = errorString;
      } else {
        this.args.setting.validationMessage = i18n("generic_error");
      }
    } finally {
      this.args.setting.isSaving = false;
    }
  }

  @action
  changeValueCallback(value) {
    this.buffered.set("value", value);
  }

  @action
  setValidationMessage(message) {
    this.args.setting.validationMessage = message;
  }

  @action
  cancel() {
    this.buffered.discardChanges();
    this.args.setting.validationMessage = null;
  }

  @action
  resetDefault() {
    this.buffered.set("value", this.args.setting.default);
    this.args.setting.validationMessage = null;
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
    this.args.setting.validationMessage = null;
  }

  _save() {
    const setting = this.buffered;
    return SiteSetting.update(setting.get("setting"), setting.get("value"), {
      updateExistingUsers: this.args.setting.updateExistingUsers,
    });
  }

  <template>
    <div
      data-setting={{@setting.setting}}
      class="row setting {{this.typeClass}} {{if this.overridden 'overridden'}}"
    >
      <div class="setting-label">
        <h3>
          {{this.settingName}}

          {{#if this.staffLogFilter}}
            <LinkTo
              @route="adminLogs.staffActionLogs"
              @query={{hash filters=this.staffLogFilter force_refresh=true}}
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
            @translatedLabel={{@setting.setDefaultValuesLabel}}
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

          <Description @description={{@setting.description}} />
        {{else}}
          <this.resolvedComponent
            {{on "keydown" this._handleKeydown}}
            @setting={{@setting}}
            @value={{this.buffered.value}}
            @preview={{this.preview}}
            @isSecret={{this.isSecret}}
            @allowAny={{this.allowAny}}
            @changeValueCallback={{this.changeValueCallback}}
            @setValidationMessage={{this.setValidationMessage}}
          />
          <SettingValidationMessage @message={{@setting.validationMessage}} />
          {{#if this.displayDescription}}
            <Description @description={{@setting.description}} />
          {{/if}}
        {{/if}}
      </div>

      {{#if this.dirty}}
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
      {{else if this.overridden}}
        {{#if @setting.secret}}
          <DButton
            @action={{this.toggleSecret}}
            @icon="far-eye-slash"
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
