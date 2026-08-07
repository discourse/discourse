import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import PostExample from "../../examples/organisms/post";
import postSource from "../../examples/organisms/post?source=file";

export default <template>
  <StyleguideExample @title="<Post>" @code={{postSource}}>
    <PostExample @post={{@dummy.postModel.transformedPost}} />
  </StyleguideExample>
</template>
