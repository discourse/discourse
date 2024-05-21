import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminFlag extends Component {
  @tracked enabled = this.args.flag.enabled;

  @action
  toggleFlagEnabled(flag) {
    this.enabled = !this.enabled;

    return ajax(`/admin/flags/${flag.id}/toggle`, {
      type: "PUT",
      contentType: "application/json",
    }).catch((error) => {
      this.enabled = !this.enabled;
      return popupAjaxError(error);
    });
  }

  <template>
    <tr class="flag">
      <td>
        <p class="flag__name">{{@flag.name}}</p>
        <p class="flag__description">{{@flag.description}}</p>
      </td>
      <td>
        <DToggleSwitch
          @state={{this.enabled}}
          class="flag__toggle {{@flag.name_key}}"
          {{on "click" (fn this.toggleFlagEnabled @flag)}}
        />
      </td>
    </tr>
  </template>
}
