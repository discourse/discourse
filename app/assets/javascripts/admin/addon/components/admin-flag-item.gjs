import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import DropdownMenu from "discourse/components/dropdown-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { SYSTEM_FLAG_IDS } from "discourse/lib/constants";
import i18n from "discourse-common/helpers/i18n";
import DMenu from "float-kit/components/d-menu";

export default class AdminFlagItem extends Component {
  @tracked enabled = this.args.flag.enabled;

  get canMove() {
    return this.args.flag.id !== SYSTEM_FLAG_IDS.notify_user;
  }

  @action
  toggleFlagEnabled(flag) {
    this.enabled = !this.enabled;

    return ajax(`/admin/config/flags/${flag.id}/toggle`, {
      type: "PUT",
    }).catch((error) => {
      this.enabled = !this.enabled;
      return popupAjaxError(error);
    });
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  moveUp() {
    this.args.moveFlagCallback(this.args.flag, "up");
    this.dMenu.close();
  }

  @action
  moveDown() {
    this.args.moveFlagCallback(this.args.flag, "down");
    this.dMenu.close();
  }

  <template>
    <tr class="admin-flag-item {{@flag.name_key}}">
      <td>
        <p class="admin-flag-item__name">{{@flag.name}}</p>
        <p class="admin-flag-item__description">{{htmlSafe
            @flag.description
          }}</p>
      </td>
      <td>
        <div class="admin-flag-item__options">
          <DToggleSwitch
            @state={{this.enabled}}
            class="admin-flag-item__toggle {{@flag.name_key}}"
            {{on "click" (fn this.toggleFlagEnabled @flag)}}
          />
          {{#if this.canMove}}
            <DMenu
              @identifier="flag-menu"
              @title={{i18n "admin.flags.more_options.title"}}
              @icon="ellipsis-v"
              @onRegisterApi={{this.onRegisterApi}}
            >
              <:content>
                <DropdownMenu as |dropdown|>
                  {{#unless @isFirstFlag}}
                    <dropdown.item>
                      <DButton
                        @label="admin.flags.more_options.move_up"
                        @icon="arrow-up"
                        @class="btn-transparent move-up"
                        @action={{this.moveUp}}
                      />
                    </dropdown.item>
                  {{/unless}}
                  {{#unless @isLastFlag}}
                    <dropdown.item>
                      <DButton
                        @label="admin.flags.more_options.move_down"
                        @icon="arrow-down"
                        @class="btn-transparent move-down"
                        @action={{this.moveDown}}
                      />
                    </dropdown.item>
                  {{/unless}}
                </DropdownMenu>
              </:content>
            </DMenu>
          {{/if}}
        </div>
      </td>
    </tr>
  </template>
}
