import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import FkControlMenuItem from "form-kit/components/control/menu/item";
import FormMeta from "form-kit/components/form/meta";
import FormText from "form-kit/components/form/text";
import FkText from "form-kit/components/text";
import DMenu from "discourse/components/d-menu";
import DropdownMenu from "discourse/components/dropdown-menu";
import icon from "discourse-common/helpers/d-icon";

export default class FkControlMenu extends Component {
  @tracked menuApi;

  @action
  registerMenuApi(api) {
    this.menuApi = api;
  }

  get headerTemplate() {
    return <template>{{yield}}</template>;
  }

  get contentTemplate() {
    return <template>
      {{yield
        (hash
          Item=(component
            FkControlMenuItem
            item=@menu.item
            setValue=@setValue
            menuApi=@menuApi
          )
          Divider=@menu.divider
        )
      }}
    </template>;
  }

  <template>
    {{#if @label}}
      <label class="d-form-select-label" for={{@name}}>
        {{@label}}
        {{#unless @required}}
          <span class="d-form-field__optional">(Optional)</span>
        {{/unless}}
      </label>
    {{/if}}

    {{#if @help}}
      <FormText>{{@help}}</FormText>
    {{/if}}

    <DMenu @onRegisterApi={{this.registerMenuApi}}>
      <:trigger>
        <span class="d-button-label">
          {{yield (hash SelectedItem=this.headerTemplate)}}
        </span>
        {{icon "angle-down"}}
      </:trigger>
      <:content>
        <DropdownMenu as |menu|>
          {{yield
            (hash)
            (component
              this.contentTemplate
              menu=menu
              setValue=@setValue
              setLabel=this.setLabel
              menuApi=this.menuApi
            )
          }}
        </DropdownMenu>
      </:content>
    </DMenu>

    <FormMeta
      @description={{@description}}
      @disabled={{@disabled}}
      @value={{@value}}
      @maxLength={{@maxLength}}
      @errorId={{@errorId}}
      @errors={{@errors}}
    />
  </template>
}
