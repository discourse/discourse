import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

const PostMetaDataReadIndicator = <template>
  <div class={{"read-state read"}} title={{i18n "post.unread"}}>
    {{icon "circle"}}
  </div>
</template>;

export default PostMetaDataReadIndicator;
