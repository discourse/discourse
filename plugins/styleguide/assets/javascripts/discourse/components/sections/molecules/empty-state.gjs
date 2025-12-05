import Component from "@glimmer/component";
import EmptyState from "discourse/components/empty-state";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class EmptyStateMolecule extends Component {
  emptyStateCode = `<EmptyState @title={{@dummy.sentence}} @body={{@dummy.short_sentence}} />`;

  <template>
    <StyleguideExample @title="<EmptyState>" @code={{this.emptyStateCode}}>
      <EmptyState @title={{@dummy.sentence}} @body={{@dummy.short_sentence}} />
    </StyleguideExample>
  </template>
}
