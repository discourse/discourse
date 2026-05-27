import Component from "@glimmer/component";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class EmptyStateMolecule extends Component {
  emptyStateCode = `<EmptyState @title={{@dummy.sentence}} @body={{@dummy.short_sentence}} />`;

  <template>
    <StyleguideExample @title="<EmptyState>" @code={{this.emptyStateCode}}>
      <DEmptyState @title={{@dummy.sentence}} @body={{@dummy.short_sentence}} />
    </StyleguideExample>
  </template>
}
