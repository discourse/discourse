import Post from "discourse/components/post";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const PostOrganism = <template>
  <StyleguideExample @title="post">
    <Post @post={{@dummy.postModel}} />
  </StyleguideExample>
</template>;

export default PostOrganism;
