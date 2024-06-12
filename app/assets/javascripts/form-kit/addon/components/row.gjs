import { hash } from "@ember/helper";
import Col from "form-kit/components/col";
import concatClass from "discourse/helpers/concat-class";

const Row = <template>
  <div class="d-form__row" ...attributes>
    {{yield (hash Col=Col)}}
  </div>
</template>;

export default Row;
