import { hash } from "@ember/helper";
import DButton from "discourse/components/d-button";
import FKField from "discourse/form-kit/components/field";
import FKText from "discourse/form-kit/components/text";

const FKControlInputGroup = <template>
  <div class="form-kit__input-group">
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
