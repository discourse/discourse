import { concat } from "@ember/helper";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

const FKCol = <template>
  <div
    class={{dConcatClass "form-kit__col" (if @size (concat "--col-" @size))}}
  >
    {{yield}}
  </div>
</template>;

export default FKCol;
