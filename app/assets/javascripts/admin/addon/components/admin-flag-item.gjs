import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminFlagItem extends Component {
  @tracked enabled = this.args.flag.enabled;

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

  <template>
    <tr class="admin-flag-item">
      <td>
        <p class="admin-flag-item__name">{{@flag.name}}</p>
        <p class="admin-flag-item__description">{{htmlSafe
            @flag.description
          }}</p>
      </td>
      <td>
        <DToggleSwitch
          @state={{this.enabled}}
          class="admin-flag-item__toggle {{@flag.name_key}}"
          {{on "click" (fn this.toggleFlagEnabled @flag)}}
        />
      </td>
    </tr>
  </template>
}
