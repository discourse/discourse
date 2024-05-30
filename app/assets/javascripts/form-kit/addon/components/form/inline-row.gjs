import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import FormCol from "form-kit/components/col";
import FormField from "form-kit/components/form/field";

const FormFieldInlineRowWrapper = <template>
  <FormCol @size={{12}}>
    <FormField
      @data={{@data}}
      @set={{@set}}
      @triggerValidationFor={{@triggerValidationFor}}
      @registerField={{@registerField}}
      @unregisterField={{@unregisterField}}
      @errors={{@errors}}
      @fields={{@fields}}
      ...attributes
    />
  </FormCol>
</template>;

export default class FormInlineRow extends Component {
  <template>
    <div class="d-form-row inline-row">
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
