import Component from "@glimmer/component";
import { array, fn } from "@ember/helper";
import { action } from "@ember/object";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class DsaClassificationSelect extends Component {
  get selection() {
    return (
      this.args.options.find((option) => option.id === this.args.field.value)
        ?.name || this.args.placeholder
    );
  }

  @action
  select(menu, value) {
    this.args.field.set(value);
    menu.close({ focusTrigger: true });
  }

  <template>
    <DMenu
      aria-describedby={{@field.describedBy}}
      aria-description={{this.selection}}
      aria-invalid={{if @field.error "true"}}
      data-value={{@field.value}}
      id={{@field.id}}
      ...attributes
      @contentClass="form-kit__control-menu-content dsa-classification-options"
      @disabled={{@field.disabled}}
      @fallbackPlacements={{array "top-start"}}
      @label={{this.selection}}
      @matchTriggerWidth={{true}}
      @modalForMobile={{true}}
      @placement="bottom-start"
      @triggerClass="form-kit__control-menu-trigger dsa-classification-select"
    >
      <:trigger>
        {{dIcon "angle-down"}}
      </:trigger>
      <:content as |menu|>
        <DDropdownMenu as |dropdown|>
          {{#each @options as |option|}}
            <dropdown.item>
              <DButton
                class={{dConcatClass
                  "btn-flat dsa-classification-option"
                  (if option.description "--with-description")
                }}
                data-value={{option.id}}
                @action={{fn this.select menu option.id}}
              >
                {{#if option.description}}
                  <span class="dsa-classification-option__texts">
                    <span
                      class="dsa-classification-option__name"
                    >{{option.name}}</span>
                    <span class="dsa-classification-option__explanation">
                      {{option.description}}
                    </span>
                  </span>
                {{else}}
                  {{option.name}}
                {{/if}}
              </DButton>
            </dropdown.item>
          {{/each}}
        </DDropdownMenu>
      </:content>
    </DMenu>
  </template>
}
