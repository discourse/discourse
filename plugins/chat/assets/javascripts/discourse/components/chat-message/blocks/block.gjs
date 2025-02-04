import { default as GlimmerComponent } from "@glimmer/component";
import Actions from "./actions";

export default class Block extends GlimmerComponent {
  get blockForType() {
    switch (this.args.definition.type) {
      case "actions":
        return Actions;
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
