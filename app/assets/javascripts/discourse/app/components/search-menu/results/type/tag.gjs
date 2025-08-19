import { or } from "truth-helpers";
import icon from "discourse/helpers/d-icon";
import discourseTag from "discourse/helpers/discourse-tag";

const Tag = <template>
  {{icon "tag"}}
  {{discourseTag (or @result.id @result) tagName="span"}}
</template>;

export default Tag;
