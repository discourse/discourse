import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { and } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

// matches ThemeScreenshotThumbnails, so the card reserves the right box
// before the image arrives
const SCREENSHOT_WIDTH = 800;
const SCREENSHOT_HEIGHT = 450;

class ThemeCard extends Component {
  @service interfaceColor;
  @service session;

  @tracked screenshotLoaded = false;

  get currentScreenshotUrl() {
    const { screenshot_dark_url, screenshot_light_url } = this.args.theme;
    return this.#showDarkScreenshot
      ? screenshot_dark_url || screenshot_light_url
      : screenshot_light_url || screenshot_dark_url;
  }

  get selected() {
    return this.args.theme.id === this.args.selectedThemeId;
  }

  get showSkeleton() {
    return !!this.currentScreenshotUrl && !this.screenshotLoaded;
  }

  get #showDarkScreenshot() {
    return (
      this.interfaceColor?.colorModeIsDark ||
      window.matchMedia("(prefers-color-scheme: dark)").matches ||
      this.session?.defaultColorSchemeIsDark
    );
  }

  // a broken screenshot should still clear the skeleton
  @action
  screenshotSettled() {
    this.screenshotLoaded = true;
  }

  <template>
    <div class="design-wizard__theme-card-wrapper">
      <label
        class="design-wizard__theme-card {{if this.selected '--selected'}}"
        data-theme-id={{@theme.id}}
      >
        <input
          type="radio"
          name="design-wizard-theme"
          value={{@theme.id}}
          checked={{this.selected}}
          disabled={{@applying}}
          class="sr-only"
          {{on "change" (fn @onSelect @theme.id)}}
        />
        {{#if (and this.selected @applying)}}
          <span class="design-wizard__theme-enabled-badge">
            <span class="spinner small design-wizard__theme-spinner"></span>
            {{i18n "design_wizard.theme.applying"}}
          </span>
        {{else if this.selected}}
          <span class="design-wizard__theme-enabled-badge">
            {{dIcon "check"}}
            {{i18n "design_wizard.theme.selected"}}
          </span>
        {{/if}}
        <span
          class="design-wizard__theme-screenshot
            {{if this.showSkeleton '--loading'}}"
        >
          {{#if this.currentScreenshotUrl}}
            <img
              class="design-wizard__theme-screenshot-image"
              src={{this.currentScreenshotUrl}}
              width={{SCREENSHOT_WIDTH}}
              height={{SCREENSHOT_HEIGHT}}
              decoding="async"
              fetchpriority="high"
              alt=""
              {{on "load" this.screenshotSettled}}
              {{on "error" this.screenshotSettled}}
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
  <fieldset
    class="design-wizard__theme-cards"
    aria-busy={{if @applying "true"}}
  >
    <legend class="sr-only">
      {{i18n "design_wizard.sections.theme"}}
    </legend>
    {{#each @themes as |theme|}}
      <ThemeCard
        @theme={{theme}}
        @selectedThemeId={{@selectedThemeId}}
        @applying={{@applying}}
        @onSelect={{@onSelect}}
      />
    {{/each}}
  </fieldset>
</template>;

export default DesignWizardThemeSection;
