import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import { eq } from "truth-helpers";
import { isHex } from "discourse/components/sidebar/section-link";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";

export default class SidebarSectionLinkPrefix extends Component {
  get prefixValue() {
    if (!this.args.prefixType && !this.args.prefixValue) {
      return;
    }

    switch (this.args.prefixType) {
      case "span":
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
        style={{if @prefixColor (htmlSafe (concat "color: " @prefixColor))}}
        class={{concatClass
          "sidebar-section-link-prefix"
          @prefixType
          @prefixCSSClass
        }}
      >
        {{#if (eq @prefixType "image")}}
          <img src={{this.prefixValue}} class="prefix-image" />
        {{else if (eq @prefixType "text")}}
          <span class="prefix-text">
            {{this.prefixValue}}
          </span>
        {{else if (eq @prefixType "icon")}}
          {{icon this.prefixValue class="prefix-icon"}}
        {{else if (eq @prefixType "span")}}
          <span
            style={{htmlSafe
              (concat
                "background: linear-gradient(90deg, " this.prefixValue ")"
              )
            }}
            class="prefix-span"
          ></span>
        {{/if}}

        {{#if @prefixBadge}}
          {{icon @prefixBadge class="prefix-badge"}}
        {{/if}}
      </span>
    {{/if}}
  </template>
}
