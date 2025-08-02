import PostList from "discourse/components/post-list";
import { i18n } from "discourse-i18n";
import StyleguideExample from "../../styleguide-example";

const StyleguidePostList = <template>
  <StyleguideExample
    @title={{i18n "styleguide.sections.post_list.empty_example"}}
  >
    <PostList @posts="" @additionalItemClasses="styleguide-post-list-item" />
  </StyleguideExample>

  <StyleguideExample
    @title={{i18n "styleguide.sections.post_list.populated_example"}}
  >
    <PostList
      @posts={{@dummy.postList}}
      @additionalItemClasses="styleguide-post-list-item"
    />
  </StyleguideExample>
</template>;

export default StyleguidePostList;
