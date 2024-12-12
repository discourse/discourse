import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as controller } from "@ember/controller";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import routeAction from "discourse/helpers/route-action";
import { cook } from "discourse/lib/text";
import { wavingHandURL } from "discourse/lib/waving-hand-url";
import { i18n } from "discourse-i18n";

export default class LoginRequired extends Component {
  @service session;
  @service site;
  @service siteSettings;
  @controller application;

  @tracked welcomeTitle;

  constructor() {
    super(...arguments);
    this.cookTitle();
  }

  async cookTitle() {
    this.welcomeTitle = await cook(
      i18n("login_required.welcome_message", {
        title: this.siteSettings.title,
      })
    );
  }

  get applicationLogoUrl() {
    if (this.site.mobileView) {
      if (
        this.session.defaultColorSchemeIsDark &&
        this.siteSettings.site_mobile_logo_dark_url
      ) {
        return this.siteSettings.site_mobile_logo_dark_url;
      } else {
        return this.siteSettings.site_mobile_logo_url;
      }
    } else {
      if (
        this.session.defaultColorSchemeIsDark &&
        this.siteSettings.site_logo_dark_url
      ) {
        return this.siteSettings.site_logo_dark_url;
      } else {
        return this.siteSettings.site_logo_url;
      }
    }
  }

  get applicationLogoDarkUrl() {
    if (this.site.mobileView) {
      if (
        this.siteSettings.site_mobile_logo_dark_url !== this.applicationLogoUrl
      ) {
        return this.siteSettings.site_mobile_logo_dark_url;
      }
    } else {
      if (this.siteSettings.site_logo_dark_url !== this.applicationLogoUrl) {
        return this.siteSettings.site_logo_dark_url;
      }
    }
  }

  <template>
    {{bodyClass "static-login"}}
    <section class="container">
      <div class="contents clearfix body-page">
        <div class="login-welcome">
          <PluginOutlet @name="above-login" />
          <PluginOutlet @name="above-static" />

          <div class="login-content">
            {{#if this.applicationLogoUrl}}
              <picture class="logo-container">
                {{#if this.applicationLogoDarkUrl}}
                  <source
                    srcset="{{this.applicationLogoDarkUrl}}"
                    media="(prefers-color-scheme: dark)"
                  />
                {{/if}}
                <img
                  src="{{this.applicationLogoUrl}}"
                  alt="{{this.siteSettings.title}}"
                  class="site-logo"
                />
              </picture>
            {{else}}
              <img src="{{(wavingHandURL)}}" alt="" class="waving-hand" />
            {{/if}}

            <div class="login-welcome__title">
              {{htmlSafe this.welcomeTitle}}
              <p class="login-welcome__description">
                {{this.siteSettings.site_description}}
              </p>
            </div>
          </div>

          <PluginOutlet @name="below-static" />
          <PluginOutlet @name="below-login" />

          <div class="body-page-button-container">
            {{#if this.application.canSignUp}}
              <DButton
                @action={{routeAction "showCreateAccount"}}
                @label="sign_up"
                class="btn-primary sign-up-button"
              />
            {{/if}}

            <DButton
              @action={{routeAction "showLogin"}}
              @label="log_in"
              class="btn-primary login-button"
            />
          </div>
        </div>
      </div>
    </section>
  </template>
}
