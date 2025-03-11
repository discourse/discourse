import i18n from "discourse/helpers/i18n";
import Blurb from "discourse/components/search-menu/results/blurb";
const Post = <template>{{i18n "search.post_format" @result}}
<Blurb @result={{@result}} /></template>;
export default Post;