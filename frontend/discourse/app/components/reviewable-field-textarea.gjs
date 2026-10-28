import { Textarea } from "@ember/component";
import { on } from "@ember/modifier";

const ReviewableFieldTextarea = <template>
  <Textarea
    class="reviewable-input-textarea"
    @value={{@value}}
    {{on "change" @valueChanged}}
  />
</template>;

export default ReviewableFieldTextarea;
