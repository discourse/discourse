import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ColorsSection from "discourse/components/design-wizard/colors-section";
import FontsSection from "discourse/components/design-wizard/fonts-section";
import HomepageSection from "discourse/components/design-wizard/homepage-section";
import LogoSection from "discourse/components/design-wizard/logo-section";
import Section from "discourse/components/design-wizard/section";
import ThemeSection from "discourse/components/design-wizard/theme-section";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export const STEPS = ["theme", "colors", "homepage"];

export default class DesignWizardControls extends Component {
  @service designWizard;

  get currentStep() {
    return STEPS[this.designWizard.stepIndex] ?? STEPS[0];
  }

  get isFirstStep() {
    return this.designWizard.stepIndex <= 0;
  }

  get isLastStep() {
    return this.designWizard.stepIndex >= STEPS.length - 1;
  }

  // a site whose default theme is custom starts with no theme selected, and
  // the later steps are meaningless until one is chosen
  get needsThemeChoice() {
    return this.currentStep === "theme" && !this.designWizard.themeId;
  }

  // a theme preview replaces the page, so anything else clicked in the meantime
  // would either be lost or save selections the reload is about to discard
  get busy() {
    return this.designWizard.applyingTheme;
  }

  get stepProgress() {
    return i18n("design_wizard.step_progress", {
      current: this.designWizard.stepIndex + 1,
      total: STEPS.length,
    });
  }

  get stepTitle() {
    return i18n(`design_wizard.steps.${this.currentStep}.title`);
  }

  get stepDescription() {
    return i18n(`design_wizard.steps.${this.currentStep}.description`);
  }

  goToStepLabel(index) {
    return i18n("design_wizard.step_label", { index: index + 1 });
  }

  @action
  async goToStep(index) {
    if (index === this.designWizard.stepIndex || this.busy) {
      return;
    }

    if (index > this.designWizard.stepIndex && this.needsThemeChoice) {
      return;
    }

    if (
      index < this.designWizard.stepIndex ||
      (await this.designWizard.saveProgress())
    ) {
      this.designWizard.setStepIndex(index);
    }
  }

  @action
  back() {
    if (this.busy) {
      return;
    }

    this.designWizard.setStepIndex(
      Math.max(this.designWizard.stepIndex - 1, 0)
    );
  }

  @action
  async next() {
    if (this.busy) {
      return;
    }

    if (await this.designWizard.saveProgress()) {
      this.designWizard.setStepIndex(
        Math.min(this.designWizard.stepIndex + 1, STEPS.length - 1)
      );
    }
  }

  @action
  selectTheme(themeId) {
    this.designWizard.selectTheme(themeId);
  }

  @action
  selectPalette(mode, pairKey) {
    this.designWizard.selectPalette(mode, pairKey);
  }

  @action
  selectPaletteMode(paletteMode) {
    this.designWizard.selectPaletteMode(paletteMode);
  }

  @action
  selectBodyFont(fontKey) {
    this.designWizard.selectBodyFont(fontKey);
  }

  @action
  selectHeadingFont(fontKey) {
    this.designWizard.selectHeadingFont(fontKey);
  }

  @action
  selectHomepage(homepage) {
    this.designWizard.selectHomepage(homepage);
  }

  @action
  selectCategoryPageStyle(value) {
    this.designWizard.selectCategoryPageStyle(value);
  }

  @action
  uploadLogo(upload) {
    this.designWizard.selectLogo(upload);
  }

  @action
  removeLogo() {
    this.designWizard.selectLogo(null);
  }

  @action
  save() {
    this.designWizard.save();
  }

  <template>
    <div class="design-wizard__content">
      <header class="design-wizard__header">
        {{#if this.designWizard.docked}}
          <span class="design-wizard__step-progress">
            {{this.stepProgress}}
          </span>
        {{/if}}
        <h2 class="design-wizard__title">{{this.stepTitle}}</h2>
        <p class="design-wizard__description">{{this.stepDescription}}</p>
      </header>

      <div class="design-wizard__sections">
        {{#if (eq this.currentStep "theme")}}
          <Section @type="theme">
            <ThemeSection
              @applying={{this.busy}}
              @currentTheme={{this.designWizard.data.current_theme}}
              @onSelect={{this.selectTheme}}
              @selectedThemeId={{this.designWizard.themeId}}
              @themes={{this.designWizard.data.themes}}
            />
          </Section>
        {{else if (eq this.currentStep "colors")}}
          <Section @title={{i18n "design_wizard.sections.logo"}} @type="logo">
            <LogoSection
              @disabled={{this.busy}}
              @logoUrl={{this.designWizard.logo}}
              @onRemove={{this.removeLogo}}
              @onUpload={{this.uploadLogo}}
            />
          </Section>

          <Section
            @title={{i18n "design_wizard.sections.colors"}}
            @type="colors"
          >
            <ColorsSection
              @darkPairs={{this.designWizard.darkPairs}}
              @lightPairs={{this.designWizard.lightPairs}}
              @onSelectPalette={{this.selectPalette}}
              @onSelectPaletteMode={{this.selectPaletteMode}}
              @paletteMode={{this.designWizard.paletteMode}}
              @selectedDarkKey={{this.designWizard.selectedDarkPair.key}}
              @selectedLightKey={{this.designWizard.selectedLightPair.key}}
              @showsDarkPalettes={{this.designWizard.showsDarkPalettes}}
              @showsLightPalettes={{this.designWizard.showsLightPalettes}}
            />
          </Section>
        {{else}}
          <Section @title={{i18n "design_wizard.sections.fonts"}} @type="fonts">
            <FontsSection
              @bodyFont={{this.designWizard.bodyFont}}
              @headingFont={{this.designWizard.headingFont}}
              @onSelectBodyFont={{this.selectBodyFont}}
              @onSelectHeadingFont={{this.selectHeadingFont}}
            />
          </Section>

          <Section
            @title={{i18n "design_wizard.sections.homepage"}}
            @type="homepage"
          >
            <HomepageSection
              @additionalHomepages={{this.designWizard.additionalHomepages}}
              @categoryPageStyle={{this.designWizard.categoryPageStyle}}
              @homepage={{this.designWizard.homepage}}
              @onSelectCategoryPageStyle={{this.selectCategoryPageStyle}}
              @onSelectHomepage={{this.selectHomepage}}
              @themeId={{this.designWizard.themeId}}
            />
          </Section>
        {{/if}}
      </div>

      <footer class="design-wizard__actions">
        <div class="design-wizard__step-dots">
          {{#each STEPS as |step index|}}
            <button
              aria-current={{if (eq step this.currentStep) "true"}}
              aria-label={{this.goToStepLabel index}}
              class="design-wizard__step-dot
                {{if (eq step this.currentStep) '--active'}}"
              disabled={{this.busy}}
              type="button"
              {{on "click" (fn this.goToStep index)}}
            ></button>
          {{/each}}
        </div>
        <DButton
          class="btn-flat design-wizard__back"
          @action={{this.back}}
          @disabled={{if this.busy true this.isFirstStep}}
          @label="design_wizard.back"
        />
        {{#if this.isLastStep}}
          <DButton
            class="btn-primary design-wizard__save"
            @action={{this.save}}
            @disabled={{this.busy}}
            @isLoading={{this.designWizard.saving}}
            @label="design_wizard.save"
          />
        {{else}}
          <DButton
            class="btn-primary design-wizard__next"
            @action={{this.next}}
            @disabled={{if this.busy true this.needsThemeChoice}}
            @isLoading={{this.designWizard.saving}}
            @label="design_wizard.next"
          />
        {{/if}}
      </footer>
    </div>
  </template>
}
