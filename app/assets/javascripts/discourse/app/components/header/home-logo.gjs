import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import getURL from "discourse/lib/get-url";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { applyValueTransformer } from "discourse/lib/transformer";
import DiscourseURL from "discourse/lib/url";
import HomeLogoContents from "./home-logo-contents";

export default class HomeLogo extends Component {
  @service session;
  @service site;
  @service siteSettings;

  darkModeAvailable = this.session.darkModeAvailable;

  get href() {
    return applyValueTransformer("home-logo-href", getURL("/"));
  }

  get showMobileLogo() {
    return this.site.mobileView && this.logoResolver("mobile_logo").length > 0;
  }

  get logoUrl() {
    return this.logoResolver("logo");
  }

  get logoUrlDark() {
    return this.logoResolver("logo", { dark: this.darkModeAvailable });
  }

  get logoSmallUrl() {
    return this.logoResolver("logo_small");
  }

  get logoSmallUrlDark() {
    return this.logoResolver("logo_small", { dark: this.darkModeAvailable });
  }

  get mobileLogoUrl() {
    return this.logoResolver("mobile_logo");
  }

  get mobileLogoUrlDark() {
    return this.logoResolver("mobile_logo", { dark: this.darkModeAvailable });
  }

  get title() {
    return this.siteSettings.title;
  }

  logoResolver(name, opts = {}) {
    let url;

    if (opts.dark) {
      // get alternative logos for browser dark dark mode switching
      url = this.siteSettings[`site_${name}_dark_url`];
    } else if (this.session.defaultColorSchemeIsDark) {
      // try dark logos first when color scheme is dark
      // this is independent of browser dark mode
      // hence the fallback to normal logos
      url =
        this.siteSettings[`site_${name}_dark_url`] ||
        this.siteSettings[`site_${name}_url`] ||
        "";
    } else {
      url = this.siteSettings[`site_${name}_url`] || "";
    }

    return applyValueTransformer("home-logo-image-url", url, {
      name,
      dark: opts.dark,
    });
  }

  @action
  click(e) {
    if (wantsNewWindow(e)) {
      return false;
    }

    e.preventDefault();
    DiscourseURL.routeToTag(e.target.closest("a"));
  }

  <template>
    <PluginOutlet @name="home-logo" @outletArgs={{hash minimized=@minimized}}>
      <div class={{concatClass (if @minimized "title--minimized") "title"}}>
        <a href={{this.href}} {{on "click" this.click}}>
          <PluginOutlet
            @name="home-logo-contents"
            @outletArgs={{hash
              logoSmallUrl=this.logoSmallUrl
              logoSmallUrlDark=this.logoSmallUrlDark
              logoUrl=this.logoUrl
              logoUrlDark=this.logoUrlDark
              minimized=@minimized
              mobileLogoUrl=this.mobileLogoUrl
              mobileLogoUrlDark=this.mobileLogoUrlDark
              showMobileLogo=this.showMobileLogo
              title=this.title
            }}
          >
            <HomeLogoContents
              @logoSmallUrl={{this.logoSmallUrl}}
              @logoSmallUrlDark={{this.logoSmallUrlDark}}
              @logoUrl={{this.logoUrl}}
              @logoUrlDark={{this.logoUrlDark}}
              @minimized={{@minimized}}
              @mobileLogoUrl={{this.mobileLogoUrl}}
              @mobileLogoUrlDark={{this.mobileLogoUrlDark}}
              @showMobileLogo={{this.showMobileLogo}}
              @title={{this.title}}
            />
          </PluginOutlet>
        </a>
      </div>
    </PluginOutlet>
  </template>
}
