import { hash } from "@ember/helper";
import FKField from "discourse/form-kit/components/fk/field";

const FKInputGroup = <template>
  <div class="form-kit__input-group">
    {{yield
      (hash
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
        )
      )
    }}
  </div>
</template>;

export default FKInputGroup;
