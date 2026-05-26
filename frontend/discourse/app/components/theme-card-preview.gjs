import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class ThemeCardPreview extends Component {
  @service interfaceColor;
  @service session;

  @tracked showingDarkScreenshot = this.#shouldShowDarkByDefault();

  get currentScreenshotUrl() {
    const { screenshot_dark_url, screenshot_light_url } = this.args.theme;
    return this.showingDarkScreenshot
      ? screenshot_dark_url || screenshot_light_url
      : screenshot_light_url || screenshot_dark_url;
  }

  get hasBothScreenshots() {
    return (
      this.args.theme.screenshot_light_url &&
      this.args.theme.screenshot_dark_url
    );
  }

  get screenshotToggleIcon() {
    return this.showingDarkScreenshot ? "sun" : "moon";
  }

  get screenshotToggleLabel() {
    return this.showingDarkScreenshot
      ? i18n("admin_onboarding_banner.select_theme.show_light_screenshot")
      : i18n("admin_onboarding_banner.select_theme.show_dark_screenshot");
  }

  #shouldShowDarkByDefault() {
    return (
      this.interfaceColor?.colorModeIsDark ||
      window.matchMedia("(prefers-color-scheme: dark)").matches ||
      this.session?.defaultColorSchemeIsDark
    );
  }

  @action
  toggleScreenshot() {
    this.showingDarkScreenshot = !this.showingDarkScreenshot;
  }

  <template>
    <div class="theme-card-preview__image-wrapper">
      {{#if this.currentScreenshotUrl}}
        <img
          class="theme-card-preview__image"
          src={{this.currentScreenshotUrl}}
          alt={{@theme.name}}
        />
        {{#if this.hasBothScreenshots}}
          <DButton
            @action={{this.toggleScreenshot}}
            @translatedAriaLabel={{this.screenshotToggleLabel}}
            @icon={{this.screenshotToggleIcon}}
            @preventFocus={{true}}
            @translatedTitle={{this.screenshotToggleLabel}}
            class="btn-flat theme-card-preview__screenshot-toggle"
          />
        {{/if}}
      {{else}}
        {{yield to="placeholder"}}
      {{/if}}
    </div>
    <div class="theme-card-preview__content">
      {{#if (has-block "title")}}
        {{yield to="title"}}
      {{else}}
        <span class="theme-card-preview__name">{{@theme.name}}</span>
      {{/if}}
      {{#if @theme.description}}
        <p class="theme-card-preview__description">{{@theme.description}}</p>
      {{/if}}
    </div>
    {{yield to="footer"}}
  </template>
}
