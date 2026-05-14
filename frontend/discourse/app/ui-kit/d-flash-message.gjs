// @ts-check
import Component from "@glimmer/component";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

const FLASH_TYPES = ["success", "error", "warning", "info"];

/**
 * A boxed inline alert message — the "flash" pattern. Use to surface
 * transient feedback inline in the page (form submission errors, save
 * confirmations) rather than as a toast/dialog. Renders nothing when
 * `@flash` is falsy, so the call-site can render the component
 * unconditionally and let it disappear when the message clears.
 *
 * Pass `@flash` for the message text and `@type` for the variant (one of
 * `"success"`, `"error"`, `"warning"`, `"info"`).
 */

/**
 * @typedef DFlashMessageSignature
 *
 * @property {object} Args
 *
 * @property {string} [Args.flash] The message text. When falsy, the component renders nothing.
 * @property {"success"|"error"|"warning"|"info"} [Args.type] Visual variant. Adds `.alert-<type>` for theming. Omit for the plain `.alert` style.
 *
 * @property {HTMLDivElement} Element
 *
 * @property {object} Blocks
 * @property {[]} Blocks.default Not used — the message text is passed via `@flash`.
 */

/** @extends {Component<DFlashMessageSignature>} */
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
