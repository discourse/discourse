import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import { bind } from "discourse-common/utils/decorators";
import AdminFlagItem from "admin/components/admin-flag-item";

export default class AdminFlags extends Component {
  @service site;
  @tracked flags = this.site.flagTypes;

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
      .catch((error) => {
        return popupAjaxError(error);
      });
  }

  <template>
    <div class="container admin-flags">
      <div class="admin-flags__header">
        <h2>{{i18n "admin.config_areas.flags.header"}}</h2>
        <LinkTo
          @route="adminConfig.flags.new"
          class="btn-primary btn btn-icon-text admin-flags__header-add-flag"
        >
          {{dIcon "plus"}}
          {{i18n "admin.config_areas.flags.add"}}
        </LinkTo>

        <h3>{{i18n "admin.config_areas.flags.subheader"}}</h3>
      </div>
      <table class="admin-flags__items grid">
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
