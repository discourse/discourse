import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";

export default class AdminConfigAreasAboutYourOrganization extends Component {
  @tracked showSavedAlert = false;

  companyName = this.args.yourOrganization.companyName.value;
  governingLaw = this.args.yourOrganization.governingLaw.value;
  cityForDisputes = this.args.yourOrganization.cityForDisputes.value;

  @action
  onCompanyNameChange(event) {
    this.companyName = event.target.value;
  }

  @action
  onGoverningLawChange(event) {
    this.governingLaw = event.target.value;
  }

  @action
  onCityForDisputesChange(event) {
    this.cityForDisputes = event.target.value;
  }

  @action
  async save() {
    this.showSavedAlert = false;
    try {
      await ajax("/admin/config/about.json", {
        type: "PUT",
        data: {
          your_organization: {
            company_name: this.companyName,
            governing_law: this.governingLaw,
            city_for_disputes: this.cityForDisputes,
          },
        },
      });
      this.showSavedAlert = true;
    } catch (err) {
      popupAjaxError(err);
    }
  }

  <template>
    <div class="control-group company-name-input">
      <label>
        <span>{{i18n "admin.config_areas.about.company_name"}}</span>
        <span class="admin-config-area-card__label-optional">{{i18n
            "admin.config_areas.about.optional"
          }}</span>
      </label>
      <p class="admin-config-area-card__additional-help">
        {{i18n "admin.config_areas.about.company_name_help"}}
      </p>
      <p class="admin-config-area-card__warning-banner">
        {{i18n "admin.config_areas.about.company_name_warning"}}
      </p>
      <input
        {{on "input" this.onCompanyNameChange}}
        type="text"
        value={{this.companyName}}
      />
    </div>
    <div class="control-group governing-law-input">
      <label>
        <span>{{i18n "admin.config_areas.about.governing_law"}}</span>
        <span class="admin-config-area-card__label-optional">{{i18n
            "admin.config_areas.about.optional"
          }}</span>
      </label>
      <p class="admin-config-area-card__additional-help">
        {{i18n "admin.config_areas.about.governing_law_help"}}
      </p>
      <input
        {{on "input" this.onGoverningLawChange}}
        type="text"
        value={{this.governingLaw}}
      />
    </div>
    <div class="control-group city-for-disputes-input">
      <label>
        <span>{{i18n "admin.config_areas.about.city_for_disputes"}}</span>
        <span class="admin-config-area-card__label-optional">{{i18n
            "admin.config_areas.about.optional"
          }}</span>
      </label>
      <p class="admin-config-area-card__additional-help">
        {{i18n "admin.config_areas.about.city_for_disputes_help"}}
      </p>
      <input
        {{on "input" this.onCityForDisputesChange}}
        type="text"
        value={{this.cityForDisputes}}
      />
    </div>
    <DButton
      @label="admin.config_areas.about.update"
      @action={{this.save}}
      class="btn-primary save-card"
    />
    {{#if this.showSavedAlert}}
      <span class="successful-save-alert">{{i18n
          "admin.config_areas.about.saved"
        }}</span>
    {{/if}}
  </template>
}
