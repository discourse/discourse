import Component from "@glimmer/component";
import { action, computed } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { inject as service } from "@ember/service";
import I18n from "I18n";

export default class ThemeSettingsEditor extends Component {
  @service dialog;

  @tracked editedContent;
  @tracked errors = [];
  @tracked saving = false;

  get saveButtonDisabled() {
    return !this.documentChanged || this.saving;
  }

  get documentChanged() {
    try {
      if (!this.editedContent) {
        return false;
      }
      const editedContentString = JSON.stringify(
        JSON.parse(this.editedContent)
      );
      const themeSettingsString = JSON.stringify(this.condensedThemeSettings());
      return editedContentString.localeCompare(themeSettingsString) !== 0;
    } catch {
      return true;
    }
  }

  _theme() {
    return this.model?.model;
  }

  condensedThemeSettings() {
    if (!this._theme()) {
      return null;
    }
    return this._theme().settings.map((setting) => ({
      setting: setting.setting,
      value: setting.value,
    }));
  }

  @computed("theme")
  get editorContents() {
    return JSON.stringify(this.condensedThemeSettings(), null, "\t");
  }

  set editorContents(value) {
    this.errors = [];
    this.editedContent = value;
  }

  // validates the following:
  // each setting must have a 'setting' and a 'value' key and no other keys
  validateSettingsKeys(settings) {
    return settings.reduce((acc, setting) => {
      if (!acc) {
        return acc;
      }
      if (!("setting" in setting)) {
        // must have a setting key
        return false;
      }
      if (!("value" in setting)) {
        // must have a value key
        return false;
      }
      if (Object.keys(setting).length > 2) {
        // at this point it's verified to have setting and value key - but must have no other keys
        return false;
      }
      return true;
    }, true);
  }

  @action
  async save() {
    this.saving = true;
    this.errors = [];
    this.success = "";
    if (!this.editedContent) {
      // no changes.
      return;
    }
    let newSettings = "";
    try {
      newSettings = JSON.parse(this.editedContent);
    } catch (e) {
      this.errors = [
        ...this.errors,
        {
          setting: I18n.t("admin.customize.syntax_error"),
          errorMessage: e.message,
        },
      ];
      return;
    }
    if (!this.validateSettingsKeys(newSettings)) {
      this.errors = [
        ...this.errors,
        {
          setting: I18n.t("admin.customize.syntax_error"),
          errorMessage: I18n.t("admin.customize.validation_settings_keys"),
        },
      ];
      this.saving = false;
      return;
    }

    const originalNames = this._theme()
      ? this._theme().settings.map((setting) => setting.setting)
      : [];
    const newNames = newSettings.map((setting) => setting.setting);
    const deletedNames = originalNames.filter(
      (originalName) => !newNames.find((newName) => newName === originalName)
    );
    const addedNames = newNames.filter(
      (newName) =>
        !originalNames.find((originalName) => originalName === newName)
    );
    if (deletedNames.length) {
      this.errors = [
        ...this.errors,
        {
          setting: deletedNames.join(", "),
          errorMessage: I18n.t("admin.customize.validation_settings_deleted"),
        },
      ];
    }
    if (addedNames.length) {
      this.errors = [
        ...this.errors,
        {
          setting: addedNames.join(","),
          errorMessage: I18n.t("admin.customize.validation_settings_added"),
        },
      ];
    }

    if (this.errors.length) {
      this.saving = false;
      return;
    }

    const changedSettings = newSettings.filter((newSetting) => {
      const originalSetting = this._theme().settings.find(
        (_originalSetting) => _originalSetting.setting === newSetting.setting
      );
      return originalSetting.value !== newSetting.value;
    });
    for (let setting of changedSettings) {
      try {
        await this.saveSetting(this._theme().id, setting);
      } catch (err) {
        const errorObjects = JSON.parse(err.jqXHR.responseText).errors.map(
          (error) => ({
            setting: setting.setting,
            errorMessage: error,
          })
        );
        this.errors = [...this.errors, ...errorObjects];
      }
    }
    if (this.errors.length === 0) {
      this.editedContent = null;
    }
    this.saving = false;
    this.dialog.cancel();
    this.model.controller.send("routeRefreshModel");
  }

  async saveSetting(themeId, setting) {
    const updateUrl = `/admin/themes/${themeId}/setting`;
    return await ajax(updateUrl, {
      type: "PUT",
      data: {
        name: setting.setting,
        value: setting.value,
      },
    });
  }
}
