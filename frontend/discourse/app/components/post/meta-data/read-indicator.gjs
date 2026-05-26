import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const PostMetaDataReadIndicator = <template>
  <div
    class={{dConcatClass "read-state" (if @post.read "read")}}
    title={{i18n "post.unread"}}
  >
    {{dIcon "circle"}}
  </div>
</template>;

export default PostMetaDataReadIndicator;
