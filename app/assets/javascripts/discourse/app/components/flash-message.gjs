import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";

const FLASH_TYPES = ["success", "error", "warning", "info"];

export default class FlashMessage extends Component {
  @action
  validateFlashType(type) {
    if (type && !FLASH_TYPES.includes(type)) {
      throw `@type must be one of ${FLASH_TYPES.join(", ")}`;
    }
  }

  <template>
    {{this.validateFlashType @type}}
    {{#if @flash}}
      <div
        class={{concatClass "alert" (if @type (concat "alert-" @type))}}
        ...attributes
      >
        {{~@flash~}}
      </div>
    {{/if}}
  </template>
}
