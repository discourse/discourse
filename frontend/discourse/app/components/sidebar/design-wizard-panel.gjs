import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ColorsSection from "discourse/components/admin-onboarding/modal/design-wizard/colors-section";
import FontsSection from "discourse/components/admin-onboarding/modal/design-wizard/fonts-section";
import Section from "discourse/components/admin-onboarding/modal/design-wizard/section";
import ThemeSection from "discourse/components/admin-onboarding/modal/design-wizard/theme-section";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const STEPS = ["theme", "colors", "fonts"];

export default class SidebarDesignWizardPanel extends Component {
  @service designWizard;

  goToStepLabel = (index) =>
    i18n("admin_onboarding_banner.design_wizard.step_label", {
      index: index + 1,
    });

  get steps() {
    return STEPS;
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

  @action
  async goToStep(index) {
    if (index === this.designWizard.stepIndex) {
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
  selectDefaultTextSize(size) {
    this.designWizard.selectDefaultTextSize(size);
  }

  @action
  save() {
    this.designWizard.save();
  }

  <template>
    <div class="sidebar-design-wizard">
      <div class="sidebar-design-wizard__header">
        <h2 class="sidebar-design-wizard__title">
          {{i18n "admin_onboarding_banner.design_wizard.title"}}
        </h2>
        <span class="sidebar-design-wizard__subtitle">
          {{i18n "admin_onboarding_banner.design_wizard.subtitle"}}
        </span>
      </div>

      <div class="sidebar-design-wizard__sections">
        {{#if (eq this.currentStep "theme")}}
          <Section
            @id="theme"
            @title={{i18n
              "admin_onboarding_banner.design_wizard.sections.theme"
            }}
          >
            <ThemeSection
              @themes={{this.designWizard.data.themes}}
              @currentTheme={{this.designWizard.data.current_theme}}
              @selectedThemeId={{this.designWizard.themeId}}
              @onSelect={{this.selectTheme}}
            />
          </Section>
        {{else if (eq this.currentStep "colors")}}
          <Section
            @id="colors"
            @title={{i18n
              "admin_onboarding_banner.design_wizard.sections.colors"
            }}
          >
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
        {{else}}
          <Section
            @id="fonts"
            @title={{i18n
              "admin_onboarding_banner.design_wizard.sections.fonts"
            }}
          >
            <FontsSection
              @bodyFont={{this.designWizard.bodyFont}}
              @headingFont={{this.designWizard.headingFont}}
              @defaultTextSize={{this.designWizard.defaultTextSize}}
              @onSelectBodyFont={{this.selectBodyFont}}
              @onSelectHeadingFont={{this.selectHeadingFont}}
              @onSelectDefaultTextSize={{this.selectDefaultTextSize}}
            />
          </Section>
        {{/if}}
      </div>

      <div class="sidebar-design-wizard__actions">
        <div class="d-image-carousel__dots sidebar-design-wizard__step-dots">
          {{#each this.steps as |step index|}}
            <button
              type="button"
              class="d-image-carousel__dot
                {{if (eq step this.currentStep) 'active'}}"
              aria-label={{this.goToStepLabel index}}
              aria-current={{if (eq step this.currentStep) "true"}}
              {{on "click" (fn this.goToStep index)}}
            ></button>
          {{/each}}
        </div>
        <DButton
          @action={{this.back}}
          @label="admin_onboarding_banner.design_wizard.back"
          @disabled={{this.isFirstStep}}
          class="btn-flat sidebar-design-wizard__back"
        />
        {{#if this.isLastStep}}
          <DButton
            @action={{this.save}}
            @label="admin_onboarding_banner.design_wizard.save"
            @isLoading={{this.designWizard.saving}}
            class="btn-primary sidebar-design-wizard__save"
          />
        {{else}}
          <DButton
            @action={{this.next}}
            @label="admin_onboarding_banner.design_wizard.next"
            @isLoading={{this.designWizard.saving}}
            class="btn-primary sidebar-design-wizard__next"
          />
        {{/if}}
      </div>
    </div>
  </template>
}
