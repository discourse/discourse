import Component from "@glimmer/component";
import { service } from "@ember/service";
import CdnImg from "discourse/components/cdn-img";
import { getURLWithCDN } from "discourse/lib/get-url";

export default class LightDarkImg extends Component {
  @service session;

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

  <template>
    {{#if this.isDarkImageAvailable}}
      <picture>
        <source
          srcset={{this.darkImgCdnSrc}}
          width={{@darkImg.width}}
          height={{@darkImg.height}}
          media="(prefers-color-scheme: dark)"
        />
        <CdnImg
          ...attributes
          @src={{this.defaultImg.url}}
          @width={{this.defaultImg.width}}
          @height={{this.defaultImg.height}}
        />
      </picture>
    {{else if @lightImg.url}}
      <CdnImg
        ...attributes
        @src={{@lightImg.url}}
        @width={{@lightImg.width}}
        @height={{@lightImg.height}}
      />
    {{/if}}
  </template>
}
