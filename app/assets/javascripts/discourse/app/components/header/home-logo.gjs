import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import DiscourseURL from "discourse/lib/url";
import icon from "discourse-common/helpers/d-icon";
import getURL from "discourse-common/lib/get-url";
import Logo from "./logo";

let hrefCallback;

export function registerHomeLogoHrefCallback(callback) {
  hrefCallback = callback;
}

export function clearHomeLogoHrefCallback() {
  hrefCallback = null;
}

export default class HomeLogo extends Component {
  @service session;
  @service site;
  @service siteSettings;

  darkModeAvailable = this.session.darkModeAvailable;

  get href() {
    if (hrefCallback) {
      return hrefCallback();
    }

    return getURL("/");
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

  logoResolver(name, opts = {}) {
    // get alternative logos for browser dark dark mode switching
    if (opts.dark) {
      return this.siteSettings[`site_${name}_dark_url`];
    }

    // try dark logos first when color scheme is dark
    // this is independent of browser dark mode
    // hence the fallback to normal logos
    if (this.session.defaultColorSchemeIsDark) {
      return (
        this.siteSettings[`site_${name}_dark_url`] ||
        this.siteSettings[`site_${name}_url`] ||
        ""
      );
    }

    return this.siteSettings[`site_${name}_url`] || "";
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
              minimized=@minimized
              logoUrl=this.logoUrl
              logoSmallUrl=this.logoSmallUrl
              showMobileLogo=this.showMobileLogo
            }}
          >
            {{#if @minimized}}
              {{#if this.logoSmallUrl}}
                <Logo
                  @key="logo-small"
                  @url={{this.logoSmallUrl}}
                  @title={{this.siteSettings.title}}
                  @darkUrl={{this.logoSmallUrlDark}}
                />
              {{else}}
                {{icon "home"}}
              {{/if}}
            {{else if this.showMobileLogo}}
              <Logo
                @key="logo-mobile"
                @url={{this.mobileLogoUrl}}
                @title={{this.siteSettings.title}}
                @darkUrl={{this.mobileLogoUrlDark}}
              />
            {{else if this.logoUrl}}
              <Logo
                @key="logo-big"
                @url={{this.logoUrl}}
                @title={{this.siteSettings.title}}
                @darkUrl={{this.logoUrlDark}}
              />
            {{else}}
              <h1 id="site-text-logo" class="text-logo">
                {{this.siteSettings.title}}
              </h1>
            {{/if}}
          </PluginOutlet>
        </a>
      </div>
    </PluginOutlet>
  </template>
}
