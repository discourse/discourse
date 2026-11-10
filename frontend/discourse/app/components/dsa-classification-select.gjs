import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";

export default class DsaClassificationSelect extends Component {
  @service a11y;

  @tracked loading = false;

  #manuallySelected = false;

  get selection() {
    return (
      this.args.options.find((option) => option.id === this.args.field.value)
        ?.name || this.args.placeholder
    );
  }

  @action
  select(menu, value) {
    this.#manuallySelected = true;
    this.args.field.set(value);
    menu.close({ focusTrigger: true });
  }

  @action
  async choose(menu) {
    this.#manuallySelected = false;
    menu.close({ focusTrigger: true });
    this.loading = true;

    try {
      const value = await this.args.chooseAction.choose();
      if (this.isDestroying) {
        return;
      }

      if (value && !this.#manuallySelected) {
        await this.args.field.set(value);
        this.a11y.announce(this.args.chooseAction.completed);
      }
    } finally {
      if (!this.isDestroying) {
        this.loading = false;
      }
    }
  }

  <template>
    <DMenu
      aria-busy={{if this.loading "true"}}
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
        {{#if this.loading}}
          {{dLoadingSpinner size="small"}}
        {{else}}
          {{dIcon "angle-down"}}
        {{/if}}
      </:trigger>
      <:content as |menu|>
        <DDropdownMenu as |dropdown|>
          {{#if @chooseAction}}
            <dropdown.item>
              <DButton
                class="btn-flat dsa-classification-select__choose"
                @action={{fn this.choose menu}}
                @disabled={{this.loading}}
                @icon={{@chooseAction.icon}}
                @translatedLabel={{@chooseAction.label}}
              />
            </dropdown.item>
            <dropdown.divider />
          {{/if}}
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
