import { hash } from "@ember/helper";
import FKField from "form-kit/components/field";
import FKText from "form-kit/components/text";
import DButton from "discourse/components/d-button";

const FKControlInputGroup = <template>
  <div class="d-form__input-group">
    {{yield
      (hash
        Text=(component FKText)
        Button=(component DButton)
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
</template>;

export default FKControlInputGroup;
