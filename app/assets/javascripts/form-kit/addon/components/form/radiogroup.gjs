import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import FormCol from "form-kit/components/col";
import FormField from "form-kit/components/form/field";
import FormText from "form-kit/components/form/text";
import concatClass from "discourse/helpers/concat-class";

class FormFieldWrapper extends Component {
  get size() {
    return this.args.size || 3;
  }

  <template>
    <FormField
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
      @disabled={{@disabled}}
      ...attributes
    />
  </template>
}

export default class FormFieldgroup extends Component {
  <template>
    <div class="d-form-fieldgroup">
      {{yield
        (hash
          Text=(component FormText)
          Field=(component
            FormFieldWrapper
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

    {{#let (uniqueId) as |labelId|}}
      <div
        role="radiogroup"
        aria-labelledby={{labelId}}
        aria-invalid={{if @invalid "true"}}
        aria-describedby={{if @invalid @errorId}}
        ...attributes
      >
        {{yield
          (hash
            Radio=(component
              HeadlessFormControlRadioComponent
              name=@name
              selected=@selected
              setValue=@setValue
            )
            Label=(component
              HeadlessFormControlRadioGroupLabelComponent id=labelId
            )
          )
        }}
      </div>
    {{/let}}
  </template>
}
