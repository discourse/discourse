import { hash } from "@ember/helper";
import DButton from "discourse/components/d-button";
import FKField from "discourse/form-kit/components/fk/field";
import FKText from "discourse/form-kit/components/fk/text";

const FKControlInputGroup = <template>
  <div class="form-kit__input-group">
    {{yield
      (hash
        Text=(component FKText)
        Button=(component DButton)
        Field=(component
          FKField
          errors=@errors
          addError=@addError
          data=@data
          set=@set
          remove=@remove
          registerField=@registerField
          unregisterField=@unregisterField
          triggerRevalidationFor=@triggerRevalidationFor
          showMeta=false
          showTitle=false
        )
      )
    }}
  </div>
</template>;

export default FKControlInputGroup;
