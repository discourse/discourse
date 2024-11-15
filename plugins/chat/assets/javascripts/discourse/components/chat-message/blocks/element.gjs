import Component from "@glimmer/component";
import Button from "./elements/button";

export default class Element extends Component {
  get elementForType() {
    switch (this.args.definition.type) {
      case "button":
        return Button;
      default:
        throw new Error(`Unknown element type: ${this.args.definition.type}`);
    }
  }

  <template>
    <this.elementForType
      @createInteraction={{@createInteraction}}
      @definition={{@definition}}
    />
  </template>
}
