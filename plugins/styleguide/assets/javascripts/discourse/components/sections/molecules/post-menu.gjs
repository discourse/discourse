import MountWidget from "discourse/components/mount-widget";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const PostMenu = <template>
  <StyleguideExample @title="post-menu">
    <MountWidget
      @widget="post-menu"
      @args={{@dummy.transformedPost}}
      @model={{@dummy.postModel}}
    />
  </StyleguideExample>
</template>;

export default PostMenu;
