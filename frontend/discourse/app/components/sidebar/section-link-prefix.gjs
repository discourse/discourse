import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { trustHTML } from "@ember/template";
import { isHex } from "discourse/components/sidebar/section-link";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";

export default class SidebarSectionLinkPrefix extends Component {
  get prefixValue() {
    if (!this.args.prefixType && !this.args.prefixValue) {
      return;
    }

    switch (this.args.prefixType) {
      case "emoji":
        return `:${this.args.prefixValue}:`;
      case "square":
        let hexValues = this.args.prefixValue;

        hexValues = hexValues.reduce((acc, color) => {
          const hexCode = isHex(color);

          if (hexCode) {
            acc.push(`#${hexCode} 50%`);
          }

          return acc;
        }, []);

        if (hexValues.length === 1) {
          hexValues.push(hexValues[0]);
        }

        return hexValues.join(", ");
      default:
        return this.args.prefixValue;
    }
  }

  <template>
    {{#if @prefixType}}
      <span
        style={{if @prefixColor (trustHTML (concat "color: " @prefixColor))}}
        class={{dConcatClass
          "sidebar-section-link-prefix"
          @prefixType
          @prefixCSSClass
        }}
      >
        {{#if (eq @prefixType "image")}}
          <img src={{this.prefixValue}} class="prefix-image" alt="" />
        {{else if (eq @prefixType "text")}}
          <span class="prefix-text">
            {{this.prefixValue}}
          </span>
        {{else if (eq @prefixType "icon")}}
          {{dIcon this.prefixValue class="prefix-icon"}}
        {{else if (eq @prefixType "emoji")}}
          {{dReplaceEmoji this.prefixValue class="prefix-emoji"}}
        {{else if (eq @prefixType "square")}}
          <span
            style={{trustHTML
              (concat
                "background: linear-gradient(90deg, " this.prefixValue ")"
              )
            }}
            class="prefix-square"
          ></span>
        {{/if}}

        {{#if @prefixBadge}}
          {{dIcon @prefixBadge class="prefix-badge"}}
        {{/if}}
      </span>
    {{/if}}
  </template>
}
