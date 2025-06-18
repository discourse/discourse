import EmptyState from "discourse/components/empty-state";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const EmptyStateMolecule = <template>
  <StyleguideExample @title="<EmptyState>">
    <EmptyState @title={{@dummy.sentence}} @body={{@dummy.short_sentence}} />
  </StyleguideExample>
</template>;

export default EmptyStateMolecule;
