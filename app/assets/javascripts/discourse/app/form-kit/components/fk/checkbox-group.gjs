import { hash } from "@ember/helper";
import FKField from "discourse/form-kit/components/fk/field";
import FKFieldset from "discourse/form-kit/components/fk/fieldset";

const FKCheckboxGroup = <template>
  <FKFieldset
    class="form-kit__checkbox-group"
    @title={{@title}}
    @description={{@description}}
  >
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
          showTitle=false
        )
      )
    }}
  </FKFieldset>
</template>;

export default FKCheckboxGroup;
