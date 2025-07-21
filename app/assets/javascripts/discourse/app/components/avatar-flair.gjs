import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { convertIconClass } from "discourse/lib/icon-library";
import { escapeExpression } from "discourse/lib/utilities";

export default class AvatarFlair extends Component {
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

    return css.length > 0 ? htmlSafe(css.join("; ")) : null;
  }

  get title() {
    return this.args.flairName;
  }

  <template>
    <div
      class={{concatClass
        "avatar-flair"
        (concat "avatar-flair-" @flairName)
        (if @flairBgColor "rounded")
        (unless this.isIcon "avatar-flair-image")
      }}
      style={{this.style}}
      title={{this.title}}
    >
      {{#if this.isIcon}}
        {{icon this.icon}}
      {{/if}}
    </div>
  </template>
}
