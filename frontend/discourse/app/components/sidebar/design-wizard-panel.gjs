import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ColorsSection from "discourse/components/admin-onboarding/modal/design-wizard/colors-section";
import FontsSection from "discourse/components/admin-onboarding/modal/design-wizard/fonts-section";
import Section from "discourse/components/admin-onboarding/modal/design-wizard/section";
import ThemeSection from "discourse/components/admin-onboarding/modal/design-wizard/theme-section";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class SidebarDesignWizardPanel extends Component {
  @service designWizard;

  @tracked openSection = "theme";

  get colorsSummary() {
    const mode = i18n(
      `admin_onboarding_banner.design_wizard.colors.${this.designWizard.effectiveColorMode}`
    );
    return `${this.designWizard.selectedPair?.name} · ${mode}`;
  }

  get fontsSummary() {
    const fontName = (key) =>
      key?.replaceAll("_", " ").replace(/\b\w/g, (c) => c.toUpperCase());
    if (this.designWizard.bodyFont === this.designWizard.headingFont) {
      return fontName(this.designWizard.bodyFont);
    }
    return `${fontName(this.designWizard.bodyFont)} / ${fontName(
      this.designWizard.headingFont
    )}`;
  }

  @action
  toggleSection(sectionId) {
    this.openSection = this.openSection === sectionId ? null : sectionId;
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
  save() {
    this.designWizard.save();
  }

  @action
  skip() {
    this.designWizard.stop();
  }

  <template>
    <div class="sidebar-design-wizard">
      <div class="sidebar-design-wizard__header">
        <span class="sidebar-design-wizard__title">
          {{i18n "admin_onboarding_banner.design_wizard.title"}}
        </span>
        <span class="sidebar-design-wizard__subtitle">
          {{i18n "admin_onboarding_banner.design_wizard.subtitle"}}
        </span>
      </div>

      <div class="sidebar-design-wizard__sections">
        <Section
          @id="theme"
          @title={{i18n "admin_onboarding_banner.design_wizard.sections.theme"}}
          @summary={{this.designWizard.selectedTheme.name}}
          @open={{eq this.openSection "theme"}}
          @onToggle={{this.toggleSection}}
        >
          <ThemeSection
            @themes={{this.designWizard.data.themes}}
            @currentTheme={{this.designWizard.data.current_theme}}
            @selectedThemeId={{this.designWizard.themeId}}
            @onSelect={{this.selectTheme}}
          />
        </Section>

        <Section
          @id="colors"
          @title={{i18n
            "admin_onboarding_banner.design_wizard.sections.colors"
          }}
          @summary={{this.colorsSummary}}
          @open={{eq this.openSection "colors"}}
          @onToggle={{this.toggleSection}}
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

        <Section
          @id="fonts"
          @title={{i18n "admin_onboarding_banner.design_wizard.sections.fonts"}}
          @summary={{this.fontsSummary}}
          @open={{eq this.openSection "fonts"}}
          @onToggle={{this.toggleSection}}
        >
          <FontsSection
            @bodyFont={{this.designWizard.bodyFont}}
            @headingFont={{this.designWizard.headingFont}}
            @onSelectBodyFont={{this.selectBodyFont}}
            @onSelectHeadingFont={{this.selectHeadingFont}}
          />
        </Section>
      </div>

      <div class="sidebar-design-wizard__actions">
        <DButton
          @action={{this.save}}
          @label="admin_onboarding_banner.design_wizard.save"
          @isLoading={{this.designWizard.saving}}
          class="btn-primary sidebar-design-wizard__save"
        />
        <DButton
          @action={{this.skip}}
          @label="admin_onboarding_banner.design_wizard.skip"
          class="btn-flat sidebar-design-wizard__skip"
        />
      </div>
    </div>
  </template>
}
