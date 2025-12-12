import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import DButton from "discourse/components/d-button";

// eslint-disable-next-line ember/no-empty-glimmer-component-classes
@block("button")
export default class BlockButton extends Component {
  <template>
    <DButton
      class={{@class}}
      @icon={{@icon}}
      @href={{@link}}
      target={{@target}}
      rel="noopener noreferrer"
      @translatedLabel={{@label}}
    />
  </template>
}
