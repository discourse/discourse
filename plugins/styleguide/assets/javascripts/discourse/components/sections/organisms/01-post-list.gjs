import { i18n } from "discourse-i18n";
import PostListExample from "../../examples/organisms/post-list";
import postListSource from "../../examples/organisms/post-list?source=file";
import PostListEmptyExample from "../../examples/organisms/post-list-empty";
import postListEmptySource from "../../examples/organisms/post-list-empty?source=file";
import StyleguideExample from "../../styleguide-example";

export default <template>
  <StyleguideExample
    @title={{i18n "styleguide.sections.post_list.empty_example"}}
    @code={{postListEmptySource}}
  >
    <PostListEmptyExample />
  </StyleguideExample>

  <StyleguideExample
    @title={{i18n "styleguide.sections.post_list.populated_example"}}
    @code={{postListSource}}
  >
    <PostListExample @posts={{@dummy.postList}} />
  </StyleguideExample>
</template>
