import { notEq } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";

const FKControlConditionalContentItem = <template>
  <div
    class={{concatClass
      "form-kit__conditional-display-content"
      (if (notEq @name @activeName) "hidden")
    }}
  >
    {{yield}}
  </div>
</template>;

export default FKControlConditionalContentItem;
