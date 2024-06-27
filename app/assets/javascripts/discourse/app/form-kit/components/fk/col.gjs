import { concat } from "@ember/helper";
import concatClass from "discourse/helpers/concat-class";

const FKCol = <template>
  <div class={{concatClass "form-kit__col" (if @size (concat "--col-" @size))}}>
    {{yield}}
  </div>
</template>;

export default FKCol;
