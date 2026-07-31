import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

class ThemeCard extends Component {
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
    <div class="design-wizard__theme-card-wrapper">
      <label
        class="design-wizard__theme-card
          {{if (eq @theme.id @selectedThemeId) '--selected'}}"
        data-theme-id={{@theme.id}}
      >
        <input
          type="radio"
          name="design-wizard-theme"
          value={{@theme.id}}
          checked={{eq @theme.id @selectedThemeId}}
          class="sr-only"
          {{on "change" (fn @onSelect @theme.id)}}
        />
        {{#if (eq @theme.id @selectedThemeId)}}
          <span class="design-wizard__theme-enabled-badge">
            {{dIcon "check"}}
            {{i18n "admin_onboarding_banner.design_wizard.theme.selected"}}
          </span>
        {{/if}}
        <span class="design-wizard__theme-screenshot">
          {{#if this.currentScreenshotUrl}}
            <img
              class="design-wizard__theme-screenshot-image"
              src={{this.currentScreenshotUrl}}
              alt=""
            />
          {{/if}}
        </span>
        <span class="design-wizard__theme-name">{{@theme.name}}</span>
        <span class="design-wizard__theme-description">
          {{@theme.description}}
        </span>
      </label>
      {{#if this.hasBothScreenshots}}
        <DButton
          @action={{this.toggleScreenshot}}
          @translatedAriaLabel={{this.toggleLabel}}
          @icon={{this.toggleIcon}}
          @translatedTitle={{this.toggleLabel}}
          class="btn-flat design-wizard__theme-screenshot-toggle"
        />
      {{/if}}
    </div>
  </template>
}

const DesignWizardThemeSection = <template>
  <fieldset class="design-wizard__theme-cards">
    <legend class="sr-only">
      {{i18n "admin_onboarding_banner.design_wizard.sections.theme"}}
    </legend>
    {{#each @themes as |theme|}}
      <ThemeCard
        @theme={{theme}}
        @selectedThemeId={{@selectedThemeId}}
        @onSelect={{@onSelect}}
      />
    {{/each}}
  </fieldset>
  {{#if @currentTheme}}
    <p class="design-wizard__custom-theme-notice">
      {{i18n
        "admin_onboarding_banner.design_wizard.theme.custom_theme_notice"
        name=@currentTheme.name
      }}
    </p>
  {{/if}}
  <PluginOutlet @name="theme-picker-modal-below-themes" />
</template>;

export default DesignWizardThemeSection;
