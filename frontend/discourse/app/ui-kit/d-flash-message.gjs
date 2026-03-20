import Component from "@glimmer/component";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

const FLASH_TYPES = ["success", "error", "warning", "info"];

export default class DFlashMessage extends Component {
  get flashClass() {
    if (this.args.type && !FLASH_TYPES.includes(this.args.type)) {
      throw `@type must be one of ${FLASH_TYPES.join(", ")}`;
    }
    return this.args.type ? `alert-${this.args.type}` : null;
  }

  <template>
    {{#if @flash}}
      <div class={{dConcatClass "alert" this.flashClass}} ...attributes>
        {{~@flash~}}
      </div>
    {{/if}}
  </template>
}
