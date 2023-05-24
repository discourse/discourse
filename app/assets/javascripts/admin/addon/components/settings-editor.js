import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { inject as service } from "@ember/service";

export default class SettingsEditor extends Component {
  @service dialog;

  @tracked editedContent = null;
  @tracked errors = [];
  @tracked saving = false;

  didInsertElement() {
    this.saving = false;
    this.errors = [];
  }

  @computed("editedContent", "saving")
  get saveButtonDisabled() {
    return !this.documentChanged || this.saving;
  }

  @computed("editedContent")
  get documentChanged() {
    try {
      if (!this.editedContent) {
        return false;
      }
      const editedContentString = JSON.stringify(
        JSON.parse(this.editedContent)
      );
      const themeSettingsString = JSON.stringify(this.condensedThemeSettings());
      const same = editedContentString.localeCompare(themeSettingsString);
      return same !== 0;
    } catch (e) {
      return true;
    }
  }

  _theme() {
    return this.theme || this.model;
  }

  condensedThemeSettings() {
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

  validateSettingsKeys(settings) {
    return settings.reduce((acc, setting) => {
      if (!acc) {
        return acc;
      }
      if (!("setting" in setting)) {
        return false;
      }
      if (!("value" in setting)) {
        return false;
      }
      if (Object.keys(setting).length > 2) {
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
          setting: "Syntax Error",
          errorMessage: e.message,
        },
      ];
      return;
    }

    if (!this.validateSettingsKeys(newSettings)) {
      this.errors = [
        ...this.errors,
        {
          setting: "Syntax Error",
          errorMessage:
            "Each item must have a 'settings' and a 'value' key and no other keys.",
        },
      ];
      this.saving = false;
      return;
    }

    const originalNames = this._theme().settings.map(
      (setting) => setting.setting
    );
    const newNames = newSettings.map((setting) => setting.setting);
    const deletedNames = originalNames.filter(
      (originalName) => !newNames.find((newName) => newName === originalName)
    );
    const addedNames = newNames.filter(
      (newName) =>
        !originalNames.find((originalName) => originalName === newName)
    );
    if (deletedNames.length > 0) {
      this.errors = [
        ...this.errors,
        {
          setting: deletedNames.join(", "),
          errorMessage:
            "These settings were deleted. Please restore them and try again.",
        },
      ];
    }
    if (addedNames.length > 0) {
      this.errors = [
        ...this.errors,
        {
          setting: addedNames.join(","),
          errorMessage:
            "These settings were added. Please remove them and try again.",
        },
      ];
    }

    if (this.errors.length > 0) {
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
