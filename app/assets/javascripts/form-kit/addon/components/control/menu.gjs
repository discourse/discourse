import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import FKControlMenuItem from "form-kit/components/control/menu/item";
import DMenu from "discourse/components/d-menu";
import DropdownMenu from "discourse/components/dropdown-menu";
import icon from "discourse-common/helpers/d-icon";

export default class FKControlMenu extends Component {
  @tracked menuApi;

  @action
  registerMenuApi(api) {
    this.menuApi = api;
  }

  <template>
    <DMenu
      @onRegisterApi={{this.registerMenuApi}}
      @triggerClass="form-kit__control-menu"
      @disabled={{@disabled}}
      @placement="bottom-start"
    >
      <:trigger>
        <span class="d-button-label">
          {{@selection}}
        </span>
        {{icon "angle-down"}}
      </:trigger>
      <:content>
        <DropdownMenu as |menu|>
          {{yield
            (hash
              Item=(component
                FKControlMenuItem item=menu.item set=@set menuApi=this.menuApi
              )
              Divider=menu.divider
            )
          }}
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
