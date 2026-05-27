import Component from "@glimmer/component";
import Actions from "./actions";
import Informative from "./informative";

export default class Block extends Component {
  get blockForType() {
    switch (this.args.definition.type) {
      case "actions":
        return Actions;
      case "informative":
        return Informative;
      default:
        throw new Error(`Unknown block type: ${this.args.definition.type}`);
    }
  }

  <template>
    <div class="chat-message__block-wrapper">
      <div class="chat-message__block">
        <this.blockForType
          @createInteraction={{@createInteraction}}
          @definition={{@definition}}
        />
      </div>
    </div>
  </template>
}
