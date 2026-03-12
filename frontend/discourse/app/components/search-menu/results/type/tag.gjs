import { or } from "discourse/truth-helpers";
import discourseTag from "discourse/ui-kit/helpers/d-discourse-tag";
import icon from "discourse/ui-kit/helpers/d-icon";

const Tag = <template>
  {{icon "tag"}}
  {{discourseTag (or @result.name @result) tagName="span"}}
</template>;

export default Tag;
