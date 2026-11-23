import Component from "@glimmer/component";
import { service } from "@ember/service";
import { getURLWithCDN } from "discourse/lib/get-url";
import type Session from "discourse/models/session";
import type InterfaceColor from "discourse/services/interface-color";
import DCdnImg from "discourse/ui-kit/d-cdn-img";

/** An uploaded image, such as a category logo. */
export interface DLightDarkImgImage {
  /** The URL of the image. */
  url?: string | null;

  /** The width of the image, in pixels. */
  width?: number | null;

  /** The height of the image, in pixels. */
  height?: number | null;
}

interface DLightDarkImgSignature {
  Args: {
    /** The image for the light color scheme, and the fallback. */
    lightImg?: DLightDarkImgImage | null;

    /** The image for the dark color scheme. It is used only with a light image. */
    darkImg?: DLightDarkImgImage | null;
  };

  Element: HTMLImageElement;
}

export default class DLightDarkImg extends Component<DLightDarkImgSignature> {
  @service declare session: Session;
  @service declare interfaceColor: InterfaceColor;

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
    const url = this.args.darkImg?.url;
    return url ? getURLWithCDN(url) : undefined;
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
          height={{@darkImg.height}}
          media={{this.darkMediaQuery}}
          srcset={{this.darkImgCdnSrc}}
          width={{@darkImg.width}}
        />
        <DCdnImg
          ...attributes
          @height={{this.defaultImg.height}}
          @src={{this.defaultImg.url}}
          @width={{this.defaultImg.width}}
        />
      </picture>
    {{else if @lightImg.url}}
      <DCdnImg
        ...attributes
        @height={{@lightImg.height}}
        @src={{@lightImg.url}}
        @width={{@lightImg.width}}
      />
    {{/if}}
  </template>
}
