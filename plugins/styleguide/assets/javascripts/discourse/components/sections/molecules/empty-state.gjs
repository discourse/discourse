import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import EmptyStateExample from "../../examples/molecules/empty-state";
import emptyStateSource from "../../examples/molecules/empty-state?source=file";

export default <template>
  <StyleguideExample @code={{emptyStateSource}} @title="<DEmptyState>">
    <EmptyStateExample />
  </StyleguideExample>
</template>
