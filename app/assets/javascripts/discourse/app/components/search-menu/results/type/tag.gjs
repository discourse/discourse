import icon from "discourse/helpers/d-icon";
import discourseTag from "discourse/helpers/discourse-tag";
import or from "truth-helpers/helpers/or";
const Tag = <template>{{icon "tag"}}
{{discourseTag (or @result.id @result) tagName="span"}}</template>;
export default Tag;