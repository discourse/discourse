import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

// Side submenu for the call menus (device pickers, layout switcher), opened
// via the `menu` service — see VoiceRoomPage.
export default class VoiceCallSubmenu extends Component {
  @action
  select(id) {
    this.args.data.onSelect(id);
    this.args.close?.();
  }

  <template>
    <DDropdownMenu as |dropdown|>
      {{#each @data.items key="id" as |item|}}
        <dropdown.item>
          <DButton
            @action={{fn this.select item.id}}
            @icon={{item.icon}}
            @translatedLabel={{item.label}}
            class={{dConcatClass
              "btn-transparent"
              (if item.selected "-selected")
            }}
          />
        </dropdown.item>
      {{/each}}
    </DDropdownMenu>
  </template>
}
