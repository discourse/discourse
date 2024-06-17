import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DMenu from "discourse/components/d-menu";
import DropdownMenu from "discourse/components/dropdown-menu";
import FKControlMenuContainer from "discourse/form-kit/components/control/menu/container";
import FKControlMenuDivider from "discourse/form-kit/components/control/menu/divider";
import FKControlMenuItem from "discourse/form-kit/components/control/menu/item";
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
      @offset={{5}}
      id={{@field.id}}
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
                FKControlMenuItem
                item=menu.item
                field=@field
                menuApi=this.menuApi
              )
              Divider=(component FKControlMenuDivider divider=menu.divider)
              Container=FKControlMenuContainer
            )
          }}
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
