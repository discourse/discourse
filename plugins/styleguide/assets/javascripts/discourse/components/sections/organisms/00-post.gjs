import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import MountWidget from "discourse/components/mount-widget";
const Post = <template><StyleguideExample @title="post">
  <MountWidget @widget="post" @model={{@dummy.postModel}} @args={{@dummy.transformedPost}} />
</StyleguideExample></template>;
export default Post;