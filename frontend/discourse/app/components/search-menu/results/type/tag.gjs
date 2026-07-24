import { or } from "discourse/truth-helpers";
import dDiscourseTag from "discourse/ui-kit/helpers/d-discourse-tag";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const Tag = <template>
  {{dIcon "tag"}}
  {{dDiscourseTag (or @result.name @result) tagName="span"}}
</template>;

export default Tag;
