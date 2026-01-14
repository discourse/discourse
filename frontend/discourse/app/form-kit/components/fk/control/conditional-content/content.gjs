import concatClass from "discourse/helpers/concat-class";
import { notEq } from "discourse/truth-helpers";

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
