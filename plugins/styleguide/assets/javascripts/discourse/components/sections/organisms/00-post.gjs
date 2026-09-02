import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import PostExample from "../../examples/organisms/post";
import postSource from "../../examples/organisms/post?source=file";

export default <template>
  <StyleguideExample @code={{postSource}} @title="<Post>">
    <PostExample @post={{@dummy.postModel.transformedPost}} />
  </StyleguideExample>
</template>
