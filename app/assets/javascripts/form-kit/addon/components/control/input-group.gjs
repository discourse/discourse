import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import FormField from "form-kit/components/form/field";
import FkText from "form-kit/components/text";

const FkTextWrapper = <template>
  <FkText ...attributes>{{yield}}</FkText>
</template>;

export default class FkControlInputGroup extends Component {
  <template>
    <div class="d-form-input-group">
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
            showMeta=false
          )
        )
      }}
    </div>
  </template>
}
