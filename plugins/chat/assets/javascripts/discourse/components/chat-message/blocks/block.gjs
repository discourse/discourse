import Component from "@glimmer/component";
import Actions from "./actions";
import Confirmation from "./confirmation";
import Informative from "./informative";

export default class Block extends Component {
  get blockForType() {
    switch (this.args.definition.type) {
      case "actions":
        return Actions;
      case "informative":
        return Informative;
      case "confirmation":
        return Confirmation;
      default:
        throw new Error(`Unknown block type: ${this.args.definition.type}`);
    }
  }

  <template>
    <div class="chat-message__block-wrapper">
      <div class="chat-message__block">
        <this.blockForType
          @cooked={{@cooked}}
          @createInteraction={{@createInteraction}}
          @decorate={{@decorate}}
          @definition={{@definition}}
        />
      </div>
    </div>
  </template>
}
