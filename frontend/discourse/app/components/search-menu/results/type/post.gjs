import Blurb from "discourse/components/search-menu/results/blurb";
import { i18n } from "discourse-i18n";

const Post = <template>
  {{i18n "search.post_format" @result}}
  <Blurb @result={{@result}} />
</template>;

export default Post;
