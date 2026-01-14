/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import TextField from "discourse/components/text-field";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n as computedI18n, propertyNotEqual } from "discourse/lib/computed";
import { i18n } from "discourse-i18n";

@classNames("house-ads-setting")
export default class HouseAdsSetting extends Component {
  adValue = "";
  saving = false;
  savingStatus = "";

  @computedI18n("name", "admin.adplugin.house_ads.%@.title") title;
  @computedI18n("name", "admin.adplugin.house_ads.%@.description") help;
  @propertyNotEqual("adValue", "value") changed;

  init() {
    super.init(...arguments);
    this.set("adValue", this.get("value"));
  }

  @action
  async save() {
    if (this.get("saving")) {
      return;
    }

    this.setProperties({
      saving: true,
      savingStatus: i18n("saving"),
    });

    try {
      await ajax(
        `/admin/plugins/pluginad/house_settings/${this.get("name")}.json`,
        {
          type: "PUT",
          data: { value: this.get("adValue") },
        }
      );
      const adSettings = this.get("adSettings");
      adSettings.set(this.get("name"), this.get("adValue"));
      this.setProperties({
        value: this.get("adValue"),
        savingStatus: i18n("saved"),
      });
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.setProperties({
        saving: false,
        savingStatus: "",
      });
    }
  }

  @action
  cancel() {
    this.set("adValue", this.get("value"));
  }

  <template>
    <label for={{this.name}}>{{this.title}}</label>
    <TextField @value={{this.adValue}} @classNames="house-ads-text-input" />
    <div class="setting-controls">
      {{#if this.changed}}
        <DButton class="ok" @action={{this.save}} @icon="check" />
        <DButton class="cancel" @action={{this.cancel}} @icon="xmark" />
      {{/if}}
    </div>
    <p class="help">{{this.help}}</p>
  </template>
}
