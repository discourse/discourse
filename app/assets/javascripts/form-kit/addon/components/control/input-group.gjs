import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import FormField from "form-kit/components/form/field";
import FkText from "form-kit/components/text";

const FkTextWrapper = <template>
  <div class="d-form-col --col-12">
    <FkText ...attributes>{{yield}}</FkText>
  </div>
</template>;

export default class FkControlInputGroup extends Component {
  <template>
    <div class="d-form-input-group d-form-row inline-row">
      {{yield
        (hash
          Text=(component FkTextWrapper)
          Field=(component
            FormField
            data=@data
            set=@set
            registerField=@registerField
            unregisterField=@unregisterField
            errors=@errors
            inputGroup=true
            showMeta=false
          )
        )
      }}
    </div>
  </template>
}
