import { notEq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

const FKControlConditionalContentItem = <template>
  <div
    class={{dConcatClass
      "form-kit__conditional-display-content"
      (if (notEq @name @activeName) "hidden")
    }}
  >
    {{yield}}
  </div>
</template>;

export default FKControlConditionalContentItem;
