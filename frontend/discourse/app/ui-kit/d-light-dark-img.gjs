// @ts-check
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { getURLWithCDN } from "discourse/lib/get-url";
/** @type {import("discourse/ui-kit/d-cdn-img.gjs")} */
import DCdnImg from "discourse/ui-kit/d-cdn-img";

/**
 * @typedef {object} LightDarkImgSource
 * @property {string} [url]
 * @property {number} [width]
 * @property {number} [height]
 */

/**
 * Renders an image that swaps between a light and (optional) dark source per the
 * active color scheme. The consumer's `...attributes` are forwarded to the
 * underlying image element.
 *
 * @extends {Component<{
 *   Args: { lightImg?: LightDarkImgSource, darkImg?: LightDarkImgSource },
 *   Element: HTMLImageElement,
 * }>}
 */
export default class DLightDarkImg extends Component {
  @service session;
  @service interfaceColor;

  get isDarkImageAvailable() {
    return (
      this.args.lightImg?.url && // the light image must be present
      this.args.darkImg?.url &&
      (this.session.defaultColorSchemeIsDark || this.session.darkModeAvailable)
    );
  }

  get defaultImg() {
    // use dark logo by default in edge case
    // when scheme is dark and dark logo is present
    if (this.session.defaultColorSchemeIsDark && this.args.darkImg) {
      return this.args.darkImg;
    }

    return this.args.lightImg;
  }

  get darkImgCdnSrc() {
    return getURLWithCDN(this.args.darkImg.url);
  }

  get darkMediaQuery() {
    if (this.interfaceColor.darkModeForced) {
      return "all";
    } else if (this.interfaceColor.lightModeForced) {
      return "none";
    } else {
      return "(prefers-color-scheme: dark)";
    }
  }

  <template>
    {{#if this.isDarkImageAvailable}}
      <picture>
        <source
          srcset={{this.darkImgCdnSrc}}
          width={{@darkImg.width}}
          height={{@darkImg.height}}
          media={{this.darkMediaQuery}}
        />
        <DCdnImg
          ...attributes
          @src={{this.defaultImg.url}}
          @width={{this.defaultImg.width}}
          @height={{this.defaultImg.height}}
        />
      </picture>
    {{else if @lightImg.url}}
      <DCdnImg
        ...attributes
        @src={{@lightImg.url}}
        @width={{@lightImg.width}}
        @height={{@lightImg.height}}
      />
    {{/if}}
  </template>
}
