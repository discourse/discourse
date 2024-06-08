import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import FKField from "form-kit/components/field";
import FKText from "form-kit/components/text";

const FKTextWrapper = <template>
  <FKText ...attributes>{{yield}}</FKText>
</template>;

export default class FKControlInputGroup extends Component {
  <template>
    <div class="d-form__input-group">
      {{yield
        (hash
          Text=(component FKTextWrapper)
          Field=(component
            FKField
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
