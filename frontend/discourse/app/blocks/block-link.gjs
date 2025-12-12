import Component from "@glimmer/component";
import { block } from "discourse/blocks";

// eslint-disable-next-line ember/no-empty-glimmer-component-classes
@block("link")
export default class BlockLink extends Component {
  <template>
    <a class={{@class}} title={{@title}} href={{@link}}>
      {{@label}}
    </a>
  </template>
}
