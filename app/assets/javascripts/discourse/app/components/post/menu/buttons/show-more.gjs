import DButton from "discourse/components/d-button";

const PostMenuShowMoreButton = <template>
  <DButton
    class="show-more-actions"
    ...attributes
    @title="show_more"
    @icon="ellipsis-h"
    @action={{@action}}
  />
</template>;

export default PostMenuShowMoreButton;
