import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";

export default class AdminConfigAreasAboutYourOrganization extends Component {
  @service toasts;

  companyName = this.args.yourOrganization.companyName.value;
  governingLaw = this.args.yourOrganization.governingLaw.value;
  cityForDisputes = this.args.yourOrganization.cityForDisputes.value;

  @action
  async save() {
    this.args.setGlobalSavingStatus(true);
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
      this.toasts.success({
        duration: 30000,
        data: {
          message: I18n.t(
            "admin.config_areas.about.toasts.your_organization_saved"
          ),
        },
      });
    } catch (err) {
      popupAjaxError(err);
    } finally {
      this.args.setGlobalSavingStatus(false);
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
        {{on "input" (withEventValue (fn (mut this.companyName)))}}
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
        {{on "input" (withEventValue (fn (mut this.governingLaw)))}}
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
        {{on "input" (withEventValue (fn (mut this.cityForDisputes)))}}
        type="text"
        value={{this.cityForDisputes}}
      />
    </div>
    <DButton
      @label="admin.config_areas.about.update"
      @action={{this.save}}
      @disabled={{@globalSavingStatus}}
      class="btn-primary admin-config-area-card__btn-save"
    />
  </template>
}
