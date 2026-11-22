import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import FKControlMenuContainer from "discourse/form-kit/components/fk/control/menu/container";
import FKControlMenuDivider from "discourse/form-kit/components/fk/control/menu/divider";
import FKControlMenuItem from "discourse/form-kit/components/fk/control/menu/item";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class FKControlMenu extends FKBaseControl {
  static controlType = "menu";

  @service site;

  @tracked menuApi;

  get selectionId() {
    return `${this.args.field.id}-selection`;
  }

  @action
  registerMenuApi(api) {
    this.menuApi = api;
  }

  <template>
    <DMenu
      aria-describedby={{@field.describedBy}}
      aria-invalid={{if @field.error "true"}}
      aria-labelledby={{if
        @field.showTitle
        (concat @field.labelId " " this.selectionId)
        (if @selection this.selectionId)
      }}
      data-value={{@field.value}}
      id={{@field.id}}
      @ariaLabel={{if this.site.mobileView @field.title}}
      @autofocus={{this.site.mobileView}}
      @contentClass="form-kit__control-menu-content"
      @disabled={{@field.disabled}}
      @matchTriggerWidth={{eq @field.format "full"}}
      @modalForMobile={{true}}
      @offset={{5}}
      @onRegisterApi={{this.registerMenuApi}}
      @placement="bottom-start"
      @preservePlacement={{@preservePlacement}}
      @triggerClass="form-kit__control-menu-trigger"
    >
      <:trigger>
        <span class="d-button-label" id={{this.selectionId}}>
          {{@selection}}
        </span>
        {{dIcon "angle-down"}}
      </:trigger>
      <:content>
        <DDropdownMenu as |menu|>
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
        </DDropdownMenu>
      </:content>
    </DMenu>
  </template>
}
