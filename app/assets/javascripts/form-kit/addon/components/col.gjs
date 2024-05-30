import { concat } from "@ember/helper";
import concatClass from "discourse/helpers/concat-class";

const Col = <template>
  <div class={{concatClass "d-form-col" (if @size (concat "--col-" @size))}}>
    {{yield}}
  </div>
</template>;

export default Col;
