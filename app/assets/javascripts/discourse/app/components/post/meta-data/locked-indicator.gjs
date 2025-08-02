import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

const PostMetaDataLockedIndicator = <template>
  <div class="post-info post-locked" title={{i18n "post.locked"}}>
    {{icon "lock"}}
  </div>
</template>;

export default PostMetaDataLockedIndicator;
