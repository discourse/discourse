import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import {
  FOUNDATION_THEME_ID,
  HORIZON_THEME_ID,
} from "discourse/lib/theme-selector";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

function themeDescription(themeId) {
  if (themeId === HORIZON_THEME_ID) {
    return i18n(
      "admin_onboarding_banner.design_wizard.theme.horizon_description"
    );
  } else if (themeId === FOUNDATION_THEME_ID) {
    return i18n(
      "admin_onboarding_banner.design_wizard.theme.foundation_description"
    );
  }
}

class ThemeScreenshot extends Component {
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

  get toggleIcon() {
    return this.showingDarkScreenshot ? "sun" : "moon";
  }

  get toggleLabel() {
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
    <span class="design-wizard-modal__theme-screenshot">
      {{#if this.currentScreenshotUrl}}
        <img
          class="design-wizard-modal__theme-screenshot-image"
          src={{this.currentScreenshotUrl}}
          alt={{@theme.name}}
        />
        {{#if this.hasBothScreenshots}}
          <DButton
            @action={{this.toggleScreenshot}}
            @translatedAriaLabel={{this.toggleLabel}}
            @icon={{this.toggleIcon}}
            @preventFocus={{true}}
            @translatedTitle={{this.toggleLabel}}
            class="btn-flat design-wizard-modal__theme-screenshot-toggle"
          />
        {{/if}}
      {{/if}}
    </span>
  </template>
}

const DesignWizardThemeSection = <template>
  <div class="design-wizard-modal__theme-cards">
    {{#each @themes as |theme|}}
      <div
        class="design-wizard-modal__theme-card
          {{if (eq theme.id @selectedThemeId) '--selected'}}"
        data-theme-id={{theme.id}}
        role="button"
        {{on "click" (fn @onSelect theme.id)}}
      >
        {{#if (eq theme.id @selectedThemeId)}}
          <span class="design-wizard-modal__theme-enabled-badge">
            {{dIcon "check"}}
            {{i18n "admin_onboarding_banner.design_wizard.theme.selected"}}
          </span>
        {{/if}}
        <ThemeScreenshot @theme={{theme}} />
        <span class="design-wizard-modal__theme-name">{{theme.name}}</span>
        <p class="design-wizard-modal__theme-description">
          {{themeDescription theme.id}}
        </p>
      </div>
    {{/each}}
  </div>
  {{#if @currentTheme}}
    <p class="design-wizard-modal__custom-theme-notice">
      {{i18n
        "admin_onboarding_banner.design_wizard.theme.custom_theme_notice"
        name=@currentTheme.name
      }}
    </p>
  {{/if}}
  <PluginOutlet @name="theme-picker-modal-below-themes" />
</template>;

export default DesignWizardThemeSection;
