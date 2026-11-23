import Component from "@glimmer/component";
import { array, concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import FloatKitCloseOnEscape from "discourse/float-kit/modifiers/close-on-escape";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class DsaClassificationSelect extends Component {
  @service site;

  get selection() {
    return (
      this.args.options.find((option) => option.id === this.args.field.value)
        ?.name ?? this.args.placeholder
    );
  }

  get selectionId() {
    return `${this.args.field.id}-selection`;
  }

  @action
  select(menu, value) {
    this.args.field.set(value);
    menu.close({ focusTrigger: true });
  }

  <template>
    <DMenu
      aria-describedby={{@field.describedBy}}
      aria-invalid={{if @field.error "true"}}
      aria-labelledby={{concat @field.labelId " " this.selectionId}}
      data-value={{@field.value}}
      id={{@field.id}}
      ...attributes
      @ariaLabel={{if this.site.mobileView @field.title}}
      @autofocus={{this.site.mobileView}}
      @contentClass="form-kit__control-menu-content dsa-classification-options"
      @disabled={{@field.disabled}}
      @fallbackPlacements={{array "top-start"}}
      @matchTriggerWidth={{true}}
      @modalForMobile={{true}}
      @offset={{5}}
      @placement="bottom-start"
      @triggerClass="form-kit__control-menu-trigger"
    >
      <:trigger>
        <span class="d-button-label" id={{this.selectionId}}>
          {{this.selection}}
        </span>
        {{dIcon "angle-down"}}
      </:trigger>
      <:content as |menu|>
        <DDropdownMenu
          {{(if
            this.site.mobileView (modifier FloatKitCloseOnEscape menu.close)
          )}}
          as |dropdown|
        >
          {{#each @options key="id" as |option|}}
            <dropdown.item>
              <DButton
                aria-current={{if (eq option.id @field.value) "true"}}
                class={{dConcatClass
                  "btn-flat"
                  (if option.description "--with-description")
                }}
                data-value={{option.id}}
                @action={{fn this.select menu option.id}}
                @suffixIcon={{if (eq option.id @field.value) "check"}}
              >
                {{#if option.description}}
                  <span>
                    <strong>{{option.name}}</strong><br />
                    <small>{{option.description}}</small>
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
