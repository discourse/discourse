import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class ThemeSettingsEditor extends Component {
  @service dialog;

  @tracked editedContent = JSON.stringify(
    this.condensedThemeSettings,
    null,
    "\t"
  );
  @tracked errors = [];
  @tracked saving = false;

  // we need to store the controller being passed in so that when we
  // call `save` we have not lost context of the argument
  customizeThemeShowController = this.args.model?.controller;

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
      const themeSettingsString = JSON.stringify(this.condensedThemeSettings);
      if (editedContentString.localeCompare(themeSettingsString) !== 0) {
        this.errors = [];
        return true;
      } else {
        return false;
      }
    } catch {
      return true;
    }
  }

  get theme() {
    return this.args.model?.model;
  }

  get condensedThemeSettings() {
    if (!this.theme) {
      return null;
    }

    return this.theme.settings.map((setting) => ({
      setting: setting.setting,
      value: setting.value,
    }));
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
          setting: i18n("admin.customize.syntax_error"),
          errorMessage: e.message,
        },
      ];
      this.saving = false;
      return;
    }

    if (!this.validateSettingsKeys(newSettings)) {
      this.errors = [
        ...this.errors,
        {
          setting: i18n("admin.customize.syntax_error"),
          errorMessage: i18n("admin.customize.validation_settings_keys"),
        },
      ];
      this.saving = false;
      return;
    }

    const originalNames = this.theme
      ? this.theme.settings.map((setting) => setting.setting)
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
          errorMessage: i18n("admin.customize.validation_settings_deleted"),
        },
      ];
    }

    if (addedNames.length) {
      this.errors = [
        ...this.errors,
        {
          setting: addedNames.join(","),
          errorMessage: i18n("admin.customize.validation_settings_added"),
        },
      ];
    }

    if (this.errors.length) {
      this.saving = false;
      return;
    }

    const changedSettings = [];

    newSettings.forEach((newSetting) => {
      const originalSetting = this.theme.settings.find(
        (_originalSetting) => _originalSetting.setting === newSetting.setting
      );

      if (originalSetting.value !== newSetting.value) {
        changedSettings.push({
          originalSetting,
          value: newSetting.value,
        });
      }
    });

    for (let changedSetting of changedSettings) {
      try {
        await this.saveSetting(this.theme.id, changedSetting);
      } catch (err) {
        const errorObjects = JSON.parse(err.jqXHR.responseText).errors.map(
          (error) => ({
            setting: changedSetting.originalSetting.setting,
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
    this.customizeThemeShowController.send("routeRefreshModel");
  }

  async saveSetting(themeId, changedSetting) {
    return await changedSetting.originalSetting.updateSetting(
      themeId,
      changedSetting.value
    );
  }
}
