import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ColorsSection from "discourse/components/design-wizard/colors-section";
import FontsSection from "discourse/components/design-wizard/fonts-section";
import HomepageSection from "discourse/components/design-wizard/homepage-section";
import Section from "discourse/components/design-wizard/section";
import ThemeSection from "discourse/components/design-wizard/theme-section";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const STEPS = ["theme", "colors", "homepage"];

export default class DesignWizardControls extends Component {
  @service designWizard;

  goToStepLabel(index) {
    return i18n("design_wizard.step_label", { index: index + 1 });
  }

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

  @action
  async goToStep(index) {
    if (index === this.designWizard.stepIndex) {
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
    this.designWizard.setStepIndex(
      Math.max(this.designWizard.stepIndex - 1, 0)
    );
  }

  @action
  async next() {
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
  selectPair(pairKey) {
    this.designWizard.selectPair(pairKey);
  }

  @action
  selectColorMode(mode) {
    this.designWizard.selectColorMode(mode);
  }

  @action
  toggleUserSelectable() {
    this.designWizard.toggleUserSelectable();
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
  save() {
    this.designWizard.save();
  }

  <template>
    <div class="design-wizard__content">
      <header class="design-wizard__header">
        <h2 id="design-wizard-title">
          {{i18n "design_wizard.title"}}
        </h2>
        <span class="design-wizard__subtitle">
          {{i18n "design_wizard.subtitle"}}
        </span>
      </header>

      <div class="design-wizard__sections">
        {{#if (eq this.currentStep "theme")}}
          <Section @title={{i18n "design_wizard.sections.theme"}}>
            <ThemeSection
              @themes={{this.designWizard.data.themes}}
              @currentTheme={{this.designWizard.data.current_theme}}
              @selectedThemeId={{this.designWizard.themeId}}
              @onSelect={{this.selectTheme}}
            />
          </Section>
        {{else if (eq this.currentStep "colors")}}
          <Section @title={{i18n "design_wizard.sections.colors"}}>
            <ColorsSection
              @pairs={{this.designWizard.pairs}}
              @selectedPairKey={{this.designWizard.selectedPair.key}}
              @selectedPairName={{this.designWizard.selectedPair.name}}
              @colorMode={{this.designWizard.effectiveColorMode}}
              @darkOnly={{this.designWizard.selectedPair.dark_only}}
              @userSelectable={{this.designWizard.palettesUserSelectable}}
              @onSelectPair={{this.selectPair}}
              @onSelectMode={{this.selectColorMode}}
              @onToggleUserSelectable={{this.toggleUserSelectable}}
            />
          </Section>

          <Section @title={{i18n "design_wizard.sections.fonts"}}>
            <FontsSection
              @bodyFont={{this.designWizard.bodyFont}}
              @headingFont={{this.designWizard.headingFont}}
              @onSelectBodyFont={{this.selectBodyFont}}
              @onSelectHeadingFont={{this.selectHeadingFont}}
            />
          </Section>
        {{else}}
          <Section @title={{i18n "design_wizard.sections.homepage"}}>
            <HomepageSection
              @themeId={{this.designWizard.themeId}}
              @homepage={{this.designWizard.homepage}}
              @categoryPageStyle={{this.designWizard.categoryPageStyle}}
              @onSelectHomepage={{this.selectHomepage}}
              @onSelectCategoryPageStyle={{this.selectCategoryPageStyle}}
            />
          </Section>
        {{/if}}
      </div>

      <footer class="design-wizard__actions">
        <div class="design-wizard__step-dots">
          {{#each STEPS as |step index|}}
            <button
              type="button"
              class="design-wizard__step-dot
                {{if (eq step this.currentStep) '--active'}}"
              aria-label={{this.goToStepLabel index}}
              aria-current={{if (eq step this.currentStep) "true"}}
              {{on "click" (fn this.goToStep index)}}
            ></button>
          {{/each}}
        </div>
        <DButton
          @action={{this.back}}
          @label="design_wizard.back"
          @disabled={{this.isFirstStep}}
          class="btn-flat design-wizard__back"
        />
        {{#if this.isLastStep}}
          <DButton
            @action={{this.save}}
            @label="design_wizard.save"
            @isLoading={{this.designWizard.saving}}
            class="btn-primary design-wizard__save"
          />
        {{else}}
          <DButton
            @action={{this.next}}
            @label="design_wizard.next"
            @isLoading={{this.designWizard.saving}}
            @disabled={{this.needsThemeChoice}}
            class="btn-primary design-wizard__next"
          />
        {{/if}}
      </footer>
    </div>
  </template>
}
