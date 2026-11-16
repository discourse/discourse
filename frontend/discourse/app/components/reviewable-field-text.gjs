import { Input } from "@ember/component";
import { on } from "@ember/modifier";

const ReviewableFieldText = <template>
  <Input
    class="reviewable-input-text"
    @value={{@value}}
    {{on "change" @valueChanged}}
  />
</template>;

export default ReviewableFieldText;
