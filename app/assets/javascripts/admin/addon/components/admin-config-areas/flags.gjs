import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { SYSTEM_FLAG_IDS } from "discourse/lib/constants";
import i18n from "discourse-common/helpers/i18n";
import { bind } from "discourse-common/utils/decorators";
import AdminFlagItem from "admin/components/admin-flag-item";
import AdminPageSubheader from "admin/components/admin-page-subheader";

export default class AdminConfigAreasFlags extends Component {
  @service site;
  @service siteSettings;
  @tracked flags = this.site.flagTypes;

  get addFlagButtonDisabled() {
    return (
      this.flags.filter(
        (flag) => !Object.values(SYSTEM_FLAG_IDS).includes(flag.id)
      ).length >= this.siteSettings.custom_flags_limit
    );
  }

  @bind
  isFirstFlag(flag) {
    return this.flags.indexOf(flag) === 1;
  }

  @bind
  isLastFlag(flag) {
    return this.flags.indexOf(flag) === this.flags.length - 1;
  }

  @action
  moveFlagCallback(flag, direction) {
    const fallbackFlags = [...this.flags];

    const flags = this.flags;

    const flagIndex = flags.indexOf(flag);
    const targetFlagIndex = direction === "up" ? flagIndex - 1 : flagIndex + 1;

    const targetFlag = flags[targetFlagIndex];

    flags[flagIndex] = targetFlag;
    flags[targetFlagIndex] = flag;

    this.flags = flags;

    return ajax(`/admin/config/flags/${flag.id}/reorder/${direction}`, {
      type: "PUT",
    }).catch((error) => {
      this.flags = fallbackFlags;
      return popupAjaxError(error);
    });
  }

  @action
  deleteFlagCallback(flag) {
    return ajax(`/admin/config/flags/${flag.id}`, {
      type: "DELETE",
    })
      .then(() => {
        this.flags.removeObject(flag);
      })
      .catch((error) => popupAjaxError(error));
  }

  <template>
    <div class="container admin-flags">
      <table class="d-admin-table admin-flags__items">
        <thead>
          <th>{{i18n "admin.config_areas.flags.description"}}</th>
          <th>{{i18n "admin.config_areas.flags.enabled"}}</th>
        </thead>
        <tbody>
          {{#each this.flags as |flag|}}
            <AdminFlagItem
              @flag={{flag}}
              @moveFlagCallback={{this.moveFlagCallback}}
              @deleteFlagCallback={{this.deleteFlagCallback}}
              @isFirstFlag={{this.isFirstFlag flag}}
              @isLastFlag={{this.isLastFlag flag}}
            />
          {{/each}}
        </tbody>
      </table>
    </div>
  </template>
}
