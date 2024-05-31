import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import FormCol from "form-kit/components/col";
import FormField from "form-kit/components/form/field";
import concatClass from "discourse/helpers/concat-class";

class FormFieldInlineRowWrapper extends Component {
  get size() {
    return this.args.size ?? 4;
  }

  <template>
    <FormCol @size={{this.size}}>
      <FormField
        @label={{@label}}
        @disabled={{@disabled}}
        @help={{@help}}
        @description={{@description}}
        @name={{@name}}
        @type={{@type}}
        @validation={{@validation}}
        @data={{@data}}
        @set={{@set}}
        @triggerValidationFor={{@triggerValidationFor}}
        @registerField={{@registerField}}
        @unregisterField={{@unregisterField}}
        @errors={{@errors}}
        @fields={{@fields}}
        @showErrors={{false}}
        ...attributes
      />
    </FormCol>
  </template>
}

export default class FormInlineRow extends Component {
  <template>
    <div class={{concatClass "d-form-row" (if @inline "inline-row")}}>
      {{yield
        (hash
          Field=(component
            FormFieldInlineRowWrapper
            data=@data
            set=@set
            triggerValidationFor=@triggerValidationFor
            registerField=@registerField
            unregisterField=@unregisterField
            errors=@errors
            fields=@fields
          )
        )
      }}
    </div>
  </template>
}
