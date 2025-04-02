import { cached, tracked } from "@glimmer/tracking";
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action, computed } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { oneWay, readOnly } from "@ember/object/computed";
import { getOwner } from "@ember/owner";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import {
  attributeBindings,
  classNameBindings,
} from "@ember-decorators/component";
import BufferedProxy from "ember-buffered-proxy/proxy";
import { Promise } from "rsvp";
import DButton from "discourse/components/d-button";
import JsonSchemaEditorModal from "discourse/components/modal/json-schema-editor";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { fmt, propertyNotEqual } from "discourse/lib/computed";
import {
  DEFAULT_USER_PREFERENCES,
  SITE_SETTING_REQUIRES_CONFIRMATION_TYPES,
} from "discourse/lib/constants";
import { deepEqual } from "discourse/lib/object";
import { humanizedSettingName } from "discourse/lib/site-settings-utils";
import { splitString } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import SettingValidationMessage from "admin/components/setting-validation-message";
import Description from "admin/components/site-settings/description";
import SiteSetting from "admin/models/site-setting";
import SiteSettingDefaultCategoriesModal from "../components/modal/site-setting-default-categories";

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

const AUTO_REFRESH_ON_SAVE = ["logo", "logo_small", "large_icon"];

@attributeBindings("setting.setting:data-setting")
@classNameBindings(":row", ":setting", "overridden", "typeClass")
export default class SiteSettingComponent extends Component {
  @service modal;
  @service router;
  @service site;
  @service dialog;
  @service siteSettingChangeTracker;

  @tracked setting = null;
  updateExistingUsers = null;
  validationMessage = null;
  isSaving = false;

  @oneWay("setting.secret") isSecret;
  @fmt("typeClass", "site-settings/%@") componentName;
  @propertyNotEqual("setting.default", "buffered.value") overridden;
  @readOnly("setting.staffLogFilter") staffLogFilter;

  get resolvedComponent() {
    return getOwner(this).resolveRegistration(
      `component:${this.componentName}`
    );
  }

  @cached
  @dependentKeyCompat
  get buffered() {
    return BufferedProxy.create({
      content: this.setting,
    });
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    super.didInsertElement(...arguments);
    this.element.addEventListener("keydown", this._handleKeydown);
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    super.willDestroyElement(...arguments);
    this.siteSettingChangeTracker.remove(this);
    this.element.removeEventListener("keydown", this._handleKeydown);
  }

  @action
  _handleKeydown(event) {
    if (
      event.key === "Enter" &&
      event.target.classList.contains("input-setting-string")
    ) {
      this.save();
    }
  }

  @computed("componentType")
  get displayDescription() {
    return this.componentType !== "bool";
  }

  @computed("componentType")
  get typeClass() {
    const componentType = this.componentType;
    return componentType.replace(/\_/g, "-");
  }

  @computed("type")
  get componentType() {
    return CUSTOM_TYPES.includes(this.type) ? this.type : "string";
  }

  @computed("setting")
  get type() {
    if (this.setting.type === "list" && this.setting.list_type) {
      return `${this.setting.list_type}_list`;
    }
  }

  @computed("buffered.value", "setting.value")
  get dirty() {
    const bufferVal = this.buffered.get("value") ?? "";
    const settingVal = this.setting?.value ?? "";
    const dirty = !deepEqual(bufferVal, settingVal);

    if (dirty) {
      this.siteSettingChangeTracker.add(this);
    } else {
      this.siteSettingChangeTracker.remove(this);
    }

    return dirty;
  }

  @computed("setting", "buffered.value")
  get preview() {
    const preview = this.setting.preview;
    const value = this.buffered.get("value");
    if (preview) {
      const escapedValue = preview.replace(/\{\{value\}\}/g, value);
      return htmlSafe(`<div class="preview">${escapedValue}</div>`);
    }
  }

  @computed("setting.setting", "setting.label")
  get settingName() {
    return humanizedSettingName(this.setting.setting, this.setting.label);
  }

  @computed("setting.anyValue")
  get allowAny() {
    return this.setting?.anyValue !== false;
  }

  @computed("buffered.value")
  get bufferedValues() {
    return splitString(this.buffered.get("value"), "|");
  }

  @computed("setting.defaultValues")
  get defaultValues() {
    return splitString(this.setting?.defaultValues, "|");
  }

  @computed("defaultValues", "bufferedValues")
  get defaultIsAvailable() {
    const { defaultValues, bufferedValues } = this;
    return (
      defaultValues.length > 0 &&
      !defaultValues.every((value) => bufferedValues.includes(value))
    );
  }

  @computed("setting")
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
  }

  @computed("isSaving", "validationMessage")
  get disableSaveButton() {
    return !!this.validationMessage || this.isSaving;
  }

  @computed("isSaving")
  get disableUndoButton() {
    return !!this.isSaving;
  }

  requiresConfirmation() {
    return (
      this.buffered.get("requires_confirmation") ===
      SITE_SETTING_REQUIRES_CONFIRMATION_TYPES.simple
    );
  }

  affectsExistingUsers() {
    return DEFAULT_USER_PREFERENCES.includes(this.buffered.get("setting"));
  }

  confirmChanges() {
    const settingKey = this.buffered.get("setting");

    return new Promise((resolve) => {
      // Fallback is needed in case the setting does not have a custom confirmation
      // prompt/confirm defined.
      this.dialog.alert({
        message: i18n(
          `admin.site_settings.requires_confirmation_messages.${settingKey}.prompt`,
          {
            translatedFallback: i18n(
              "admin.site_settings.requires_confirmation_messages.default.prompt"
            ),
          }
        ),
        buttons: [
          {
            label: i18n(
              `admin.site_settings.requires_confirmation_messages.${settingKey}.confirm`,
              {
                translatedFallback: i18n(
                  "admin.site_settings.requires_confirmation_messages.default.confirm"
                ),
              }
            ),
            class: "btn-primary",
            action: () => resolve(true),
          },
          {
            label: i18n("no_value"),
            class: "btn-default",
            action: () => resolve(false),
          },
        ],
      });
    });
  }

  async configureBackfill() {
    const key = this.buffered.get("setting");

    const data = {
      [key]: this.buffered.get("value"),
    };

    const result = await ajax(`/admin/site_settings/${key}/user_count.json`, {
      type: "PUT",
      data,
    });

    const count = result.user_count;

    if (count > 0) {
      await this.modal.show(SiteSettingDefaultCategoriesModal, {
        model: {
          siteSetting: { count, key: key.replaceAll("_", " ") },
          setUpdateExistingUsers: this.setUpdateExistingUsers,
        },
      });
    }
  }

  requiresReload() {
    return AUTO_REFRESH_ON_SAVE.includes(this.setting.setting);
  }

  @action
  async save() {
    try {
      this.isSaving = true;

      await this._save();

      this.validationMessage = null;
      this.buffered.applyChanges();
      if (this.requiresReload()) {
        this.afterSave?.();
      }
    } catch (e) {
      const json = e.jqXHR?.responseJSON;
      if (json?.errors) {
        let errorString = json.errors[0];

        if (json.html_message) {
          errorString = htmlSafe(errorString);
        }

        this.validationMessage = errorString;
      } else {
        this.validationMessage = i18n("generic_error");
      }
    } finally {
      this.isSaving = false;
    }
  }

  async _save() {
    const setting = this.buffered;
    return SiteSetting.update(setting.get("setting"), setting.get("value"), {
      updateExistingUsers: this.updateExistingUsers,
    });
  }

  @action
  async update() {
    if (this.requiresConfirmation()) {
      const confirm = await this.confirmChanges();

      if (!confirm) {
        return;
      }
    }

    if (this.affectsExistingUsers()) {
      await this.configureBackfill();
    }

    await this.save();
  }

  @action
  setUpdateExistingUsers(value) {
    this.updateExistingUsers = value;
  }

  @action
  changeValueCallback(value) {
    this.buffered.set("value", value);
  }

  @action
  setValidationMessage(message) {
    this.validationMessage = message;
  }

  @action
  cancel() {
    this.buffered.discardChanges();
    this.validationMessage = null;
  }

  @action
  resetDefault() {
    this.buffered.set("value", this.setting.default);
    this.validationMessage = null;
  }

  @action
  toggleSecret() {
    this.toggleProperty("isSecret");
  }

  @action
  setDefaultValues() {
    this.buffered.set(
      "value",
      this.bufferedValues.concat(this.defaultValues).uniq().join("|")
    );
    this.validationMessage = null;
    return false;
  }

  <template>
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
      {{else}}
        <this.resolvedComponent
          @setting={{this.setting}}
          @value={{this.buffered.value}}
          @preview={{this.preview}}
          @isSecret={{this.isSecret}}
          @allowAny={{this.allowAny}}
          @changeValueCallback={{this.changeValueCallback}}
          @setValidationMessage={{this.setValidationMessage}}
        />
        <SettingValidationMessage @message={{this.validationMessage}} />
        {{#if this.displayDescription}}
          <Description @description={{this.setting.description}} />
        {{/if}}
      {{/if}}
    </div>

    {{#if this.dirty}}
      <div class="setting-controls">
        <DButton
          @action={{this.update}}
          @icon="check"
          @disabled={{this.disableSaveButton}}
          @ariaLabel="admin.settings.save"
          class="ok setting-controls__ok"
        />
        <DButton
          @action={{this.cancel}}
          @icon="xmark"
          @disabled={{this.disableUndoButton}}
          @ariaLabel="admin.settings.cancel"
          class="cancel setting-controls__cancel"
        />
      </div>
    {{else if this.overridden}}
      {{#if this.setting.secret}}
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
  </template>
}
