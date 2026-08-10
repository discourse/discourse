import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import { eq } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

class ThemeCard extends Component {
  @service interfaceColor;
  @service session;

  get currentScreenshotUrl() {
    const { screenshot_dark_url, screenshot_light_url } = this.args.theme;
    return this.#showDarkScreenshot
      ? screenshot_dark_url || screenshot_light_url
      : screenshot_light_url || screenshot_dark_url;
  }

  get #showDarkScreenshot() {
    return (
      this.interfaceColor?.colorModeIsDark ||
      window.matchMedia("(prefers-color-scheme: dark)").matches ||
      this.session?.defaultColorSchemeIsDark
    );
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
            {{i18n "design_wizard.theme.selected"}}
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
    </div>
  </template>
}

const DesignWizardThemeSection = <template>
  {{#if @currentTheme}}
    <p class="design-wizard__custom-theme-notice">
      {{i18n "design_wizard.theme.custom_theme_notice" name=@currentTheme.name}}
    </p>
  {{/if}}
  <fieldset class="design-wizard__theme-cards">
    <legend class="sr-only">
      {{i18n "design_wizard.sections.theme"}}
    </legend>
    {{#each @themes as |theme|}}
      <ThemeCard
        @theme={{theme}}
        @selectedThemeId={{@selectedThemeId}}
        @onSelect={{@onSelect}}
      />
    {{/each}}
  </fieldset>
</template>;

export default DesignWizardThemeSection;
