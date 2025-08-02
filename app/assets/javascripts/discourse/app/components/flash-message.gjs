import Component from "@glimmer/component";
import concatClass from "discourse/helpers/concat-class";

const FLASH_TYPES = ["success", "error", "warning", "info"];

export default class FlashMessage extends Component {
  get flashClass() {
    if (this.args.type && !FLASH_TYPES.includes(this.args.type)) {
      throw `@type must be one of ${FLASH_TYPES.join(", ")}`;
    }
    return this.args.type ? `alert-${this.args.type}` : null;
  }

  <template>
    {{#if @flash}}
      <div class={{concatClass "alert" this.flashClass}} ...attributes>
        {{~@flash~}}
      </div>
    {{/if}}
  </template>
}
