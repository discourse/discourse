import { hash } from "@ember/helper";
import FKCol from "discourse/form-kit/components/fk/col";

const FKRow = <template>
  <div class="form-kit__row" ...attributes>
    {{yield (hash Col=FKCol)}}
  </div>
</template>;

export default FKRow;
