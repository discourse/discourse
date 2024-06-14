import { hash } from "@ember/helper";
import Col from "discourse/form-kit/components/col";

const Row = <template>
  <div class="form-kit__row" ...attributes>
    {{yield (hash Col=Col)}}
  </div>
</template>;

export default Row;
