import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import FormField from "form-kit/components/form/field";

const ColWrapper = <template>
  <div class="d-form-col --col-12">
    <@component
      @name={{@name}}
      @data={{@data}}
      @set={{@set}}
      @registerField={{@registerField}}
      @unregisterField={{@unregisterField}}
      @errors={{@errors}}
    >
      {{yield}}
    </@component>
  </div>
</template>;

export default class FkControlInputGroup extends Component {
  <template>
    <div class="d-form-row inline-row">
      {{yield
        (hash
          Field=(component
            ColWrapper
            component=FormField
            data=@data
            set=@set
            registerField=@registerField
            unregisterField=@unregisterField
            errors=@errors
            inputGroup=true
          )
        )
      }}
    </div>
  </template>
}
