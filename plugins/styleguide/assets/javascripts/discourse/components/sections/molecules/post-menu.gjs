import PostMenu from "discourse/components/post/menu";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const PostMenuMolecule = <template>
  <StyleguideExample @title="post-menu">
    <PostMenu @post={{@dummy.postModel}} />
  </StyleguideExample>
</template>;

export default PostMenuMolecule;
