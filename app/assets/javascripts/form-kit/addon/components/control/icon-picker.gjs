import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import FormMeta from "form-kit/components/form/meta";
import FormText from "form-kit/components/form/text";
import IconPicker from "select-kit/components/icon-picker";

export default class FkControlIconSelector extends Component {
  @action
  handleInput(value) {
    this.args.setValue(value);
  }

  @action
  handleDestroy() {
    this.args.setValue(undefined);
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

    <IconPicker
      @value={{@value}}
      @options={{hash maximum=1}}
      @onChange={{this.handleInput}}
      {{willDestroy this.handleDestroy}}
    />

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
