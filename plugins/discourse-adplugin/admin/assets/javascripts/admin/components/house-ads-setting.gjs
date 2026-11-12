import Component from "@glimmer/component";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { deepEqual } from "discourse/lib/object";
import { resettableTracked } from "discourse/lib/tracked-tools";
import DButton from "discourse/ui-kit/d-button";
import DTextField from "discourse/ui-kit/d-text-field";
import { i18n } from "discourse-i18n";

export default class HouseAdsSetting extends Component {
  @resettableTracked adValue = this.args.value;

  saving = false;

  get title() {
    return i18n(`admin.adplugin.house_ads.${this.args.name}.title`);
  }

  get help() {
    return i18n(`admin.adplugin.house_ads.${this.args.name}.description`);
  }

  get changed() {
    return !deepEqual(this.adValue, this.args.value);
  }

  @action
  async save() {
    if (this.saving) {
      return;
    }

    this.saving = true;

    try {
      await ajax(
        `/admin/plugins/discourse-adplugin/house-settings/${this.args.name}`,
        {
          type: "PUT",
          data: { value: this.adValue },
        }
      );
      this.args.adSettings.set(this.args.name, this.adValue);
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.saving = false;
    }
  }

  @action
  cancel() {
    this.adValue = this.args.value;
  }

  <template>
    <div class="house-ads-setting" ...attributes>
      <label for={{@name}}>{{this.title}}</label>
      <DTextField @classNames="house-ads-text-input" @value={{this.adValue}} />
      <div class="setting-controls">
        {{#if this.changed}}
          <DButton class="ok" @action={{this.save}} @icon="check" />
          <DButton class="cancel" @action={{this.cancel}} @icon="xmark" />
        {{/if}}
      </div>
      <p class="help">{{this.help}}</p>
    </div>
  </template>
}
