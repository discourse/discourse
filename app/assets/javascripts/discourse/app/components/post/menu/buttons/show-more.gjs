import DButton from "discourse/components/d-button";

const ShowMoreButton = <template>
  <DButton
    class="show-more-actions"
    ...attributes
    @title="show_more"
    @icon="ellipsis-h"
    @action={{@action}}
  />
</template>;

export default ShowMoreButton;
