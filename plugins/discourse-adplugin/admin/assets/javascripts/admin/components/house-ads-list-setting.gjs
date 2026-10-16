import { action } from "@ember/object";
import { makeArray } from "discourse/lib/helpers";
import DButton from "discourse/ui-kit/d-button";
import HouseAdsChooser from "./house-ads-chooser.js";
import HouseAdsSetting from "./house-ads-setting.gjs";

export default class HouseAdsListSetting extends HouseAdsSetting {
  get adNames() {
    return this.args.allAds?.map?.((item) => item.name) ?? [];
  }

  @action
  changeAdValue(value) {
    this.adValue = makeArray(value).join("|");
  }

  <template>
    <div class="house-ads-setting house-ads-list-setting" ...attributes>
      <label for={{@name}}>{{this.title}}</label>
      <HouseAdsChooser
        @choices={{this.adNames}}
        @onChange={{this.changeAdValue}}
        @settingValue={{this.adValue}}
      />
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
