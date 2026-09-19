import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { trustHTML } from "@ember/template";
import { convertIconClass } from "discourse/lib/icon-library";
import { escapeExpression } from "discourse/lib/utilities";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class DAvatarFlair extends Component {
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
