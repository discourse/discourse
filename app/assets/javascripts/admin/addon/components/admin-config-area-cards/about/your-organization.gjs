import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import i18n from "discourse-common/helpers/i18n";

export default class AdminConfigAreasAboutYourOrganization extends Component {
  @action
  save() {
    this.args.saveCallback();
    // eslint-disable-next-line no-console
    console.log("your organization");
  }

  <template>
    <div class="control-group">
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
      <input type="text" />
    </div>
    <div class="control-group">
      <label>
        <span>{{i18n "admin.config_areas.about.governing_law"}}</span>
        <span class="admin-config-area-card__label-optional">{{i18n
            "admin.config_areas.about.optional"
          }}</span>
      </label>
      <p class="admin-config-area-card__additional-help">
        {{i18n "admin.config_areas.about.governing_law_help"}}
      </p>
      <input type="text" />
    </div>
    <div class="control-group">
      <label>
        <span>{{i18n "admin.config_areas.about.city_for_disputes"}}</span>
        <span class="admin-config-area-card__label-optional">{{i18n
            "admin.config_areas.about.optional"
          }}</span>
      </label>
      <p class="admin-config-area-card__additional-help">
        {{i18n "admin.config_areas.about.city_for_disputes_help"}}
      </p>
      <input type="text" />
    </div>
    <DButton
      @label="admin.config_areas.about.update"
      @action={{this.save}}
      class="btn-primary"
    />
  </template>
}
