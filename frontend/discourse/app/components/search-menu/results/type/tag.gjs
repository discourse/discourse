import icon from "discourse/helpers/d-icon";
import discourseTag from "discourse/helpers/discourse-tag";
import { or } from "discourse/truth-helpers";

const Tag = <template>
  {{icon "tag"}}
  {{discourseTag (or @result.id @result) tagName="span"}}
</template>;

export default Tag;
