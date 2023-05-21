import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

export default class SettingsEditor extends Component {
  @tracked editedContent = null;

  @tracked errors = [];
  @tracked success = "";

  @computed("editedContent")
  get buttonDisabled() {
    return !(this.editedContent && this.editedContent.length > 0);
  }

  _theme() {
    return this.theme || this.model;
  }

  @computed("theme")
  get editorContents() {
    const settings = this._theme().settings.map(setting => ({ setting: setting.setting, value: setting.value }));
    return JSON.stringify(settings, null, "\t");
  }


  set editorContents(value) {
    this.editedContent = value;
  }

  @action
  async save() {
    this.errors = [];
    this.success = "";
    if (!this.editedContent) { // no changes.
      return;
    }
    const newSettings = JSON.parse(this.editedContent);
    const originalNames = this._theme().settings.map(setting => setting.setting);
    const newNames = newSettings.map(setting => setting.setting);
    const deletedNames = originalNames.filter(originalName => (!newNames.find(newName => newName === originalName)));
    const addedNames = newNames.filter(newName => (!originalNames.find(originalName => originalName === newName)));
    if (deletedNames.length > 0) {
      this.errors = [...this.errors, {
        setting: deletedNames.join(", "),
        errorMessage: "These settings were deleted. Please restore them and try again."
      }];
    }
    if (addedNames.length > 0) {
      this.errors = [...this.errors, {
        setting: addedNames.join(","),
        errorMessage: "These settings were added. Please remove them and try again."
      }];
    }

    if (this.errors.length > 0) {
      return;
    }

    const changedSettings = newSettings.filter(newSetting => {
      const originalSetting = this._theme().settings.find(_originalSetting =>
        _originalSetting.setting === newSetting.setting);
      return originalSetting.value !== newSetting.value;
    });
    for (let setting of changedSettings) {
      try {
        await this.saveSetting(this._theme().id, setting);
      } catch (err) {
        const errorObjects = JSON.parse(err.jqXHR.responseText).errors.map(error => ({
          setting: setting.setting,
          errorMessage: error
        }));
        this.errors = [...this.errors, ...errorObjects];
      }
    }
    if (this.errors.length === 0) {
      this.success = "success!";
    }

  }

  async saveSetting(themeId, setting) {
    const updateUrl = `/admin/themes/${themeId}/setting`;
    return await ajax(updateUrl, {
      type: "PUT",
      data: {
        name: setting.setting,
        value: setting.value
      }
    });
  }

}
