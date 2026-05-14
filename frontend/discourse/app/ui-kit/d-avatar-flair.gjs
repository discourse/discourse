// @ts-check
import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { cached } from "@glimmer/tracking";
import { assert } from "@ember/debug";
import { concat } from "@ember/helper";
import { trustHTML } from "@ember/template";
import { convertIconClass } from "discourse/lib/icon-library";
import { escapeExpression } from "discourse/lib/utilities";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

/**
 * A small badge rendered alongside an avatar to denote a flair (group flair,
 * primary group icon, etc.). The same component renders an icon flair or an
 * image flair depending on `@flairUrl`: a value containing `/` is treated as
 * an image URL, anything else is looked up via the icon library. Background
 * and foreground colors come from `@flairBgColor` and `@flairColor` as raw
 * hex strings without the leading `#`.
 *
 * @example
 * <DAvatarFlair
 *   @flairUrl="bars"
 *   @flairName="staff"
 *   @flairBgColor="CC0000"
 *   @flairColor="FFFFFF"
 * />
 */

/**
 * @typedef DAvatarFlairSignature
 *
 * @property {object} Args
 *
 * @property {string} Args.flairUrl Required. An icon name (e.g. `"bars"`) or an image URL. The component switches rendering modes based on whether the value contains a `/`.
 * @property {string} [Args.flairName] Used for the `title` tooltip and a stable `avatar-flair-<name>` class hook.
 * @property {string} [Args.flairBgColor] Hex color without the leading `#`, used as the background color. Also enables the `rounded` class.
 * @property {string} [Args.flairColor] Hex color without the leading `#`, used as the foreground color of the icon.
 *
 * @property {HTMLDivElement} Element
 *
 * @property {object} Blocks
 * @property {[]} Blocks.default Not used.
 */

/** @extends {Component<DAvatarFlairSignature>} */
export default class DAvatarFlair extends Component {
  @cached
  get validateArgs() {
    if (DEBUG) {
      assert(
        "[d-avatar-flair] @flairUrl is required",
        this.args.flairUrl != null
      );
    }
    return null;
  }

  get icon() {
    return convertIconClass(this.args.flairUrl);
  }

  get isIcon() {
    return this.args.flairUrl && !this.args.flairUrl.includes("/");
  }

  get style() {
    const css = [];

    if (!this.isIcon) {
      css.push(
        "background-image: url(" + escapeExpression(this.args.flairUrl) + ")"
      );
    }

    if (this.args.flairBgColor) {
      css.push(
        "background-color: #" + escapeExpression(this.args.flairBgColor)
      );
    }

    if (this.args.flairColor) {
      css.push("color: #" + escapeExpression(this.args.flairColor));
    }

    return css.length > 0 ? trustHTML(css.join("; ")) : null;
  }

  get title() {
    return this.args.flairName;
  }

  <template>
    {{this.validateArgs}}
    <div
      class={{dConcatClass
        "avatar-flair"
        (concat "avatar-flair-" @flairName)
        (if @flairBgColor "rounded")
        (unless this.isIcon "avatar-flair-image")
      }}
      style={{this.style}}
      title={{this.title}}
    >
      {{#if this.isIcon}}
        {{dIcon this.icon}}
      {{/if}}
    </div>
  </template>
}
