import Component from "@glimmer/component";
import type { TrustedHTML } from "@ember/template";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

const FLASH_TYPES = ["success", "error", "warning", "info"] as const;

export type FlashType = (typeof FLASH_TYPES)[number];

interface DFlashMessageSignature {
  Args: {
    /** The message to display. Accepts a plain string or trusted HTML. */
    flash?: string | TrustedHTML;

    /** The severity of the message. */
    type?: FlashType;
  };

  Element: HTMLDivElement;
}

export default class DFlashMessage extends Component<DFlashMessageSignature> {
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
