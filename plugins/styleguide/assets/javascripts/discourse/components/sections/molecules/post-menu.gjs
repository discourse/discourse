import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import PostMenuExample from "../../examples/molecules/post-menu";
import postMenuSource from "../../examples/molecules/post-menu?source=file";

export default <template>
  <StyleguideExample @title="<PostMenu>" @code={{postMenuSource}}>
    <PostMenuExample @post={{@dummy.transformedPost}} />
  </StyleguideExample>
</template>
