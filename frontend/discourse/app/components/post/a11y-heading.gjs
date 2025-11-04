import { concat } from "@ember/helper";

const PostA11yHeading = <template>
  <h2 class="sr-only" id={{concat "post-heading-" @post.post_number}}>
    {{@text}}
  </h2>
</template>;

export default PostA11yHeading;
