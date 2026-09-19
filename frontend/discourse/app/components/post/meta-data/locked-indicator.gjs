import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const PostMetaDataLockedIndicator = <template>
  <div class="post-info post-locked" title={{i18n "post.locked"}}>
    {{dIcon "lock"}}
  </div>
</template>;

export default PostMetaDataLockedIndicator;
