import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import EmptyState from "discourse/components/empty-state";
const EmptyState0 = <template><StyleguideExample @title="<EmptyState>">
  <EmptyState @title={{@dummy.sentence}} @body={{@dummy.short_sentence}} />
</StyleguideExample></template>;
export default EmptyState0;