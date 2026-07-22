import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ColorsSection from "discourse/components/admin-onboarding/modal/design-wizard/colors-section";
import FontsSection from "discourse/components/admin-onboarding/modal/design-wizard/fonts-section";
import HomepageSection from "discourse/components/admin-onboarding/modal/design-wizard/homepage-section";
import PreviewPane from "discourse/components/admin-onboarding/modal/design-wizard/preview";
import Section from "discourse/components/admin-onboarding/modal/design-wizard/section";
import ThemeSection from "discourse/components/admin-onboarding/modal/design-wizard/theme-section";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { HORIZON_THEME_ID, setLocalTheme } from "discourse/lib/theme-selector";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class DesignWizardModal extends Component {
  @service siteSettings;

  @tracked data;
  @tracked loading = true;
  @tracked saving = false;
  @tracked openSection = "theme";
  @tracked themeId;
  @tracked colorMode = "light";
  @tracked palettesUserSelectable = false;
  @tracked bodyFont;
  @tracked headingFont;
  @tracked homepage;
  @tracked categoryPageStyle;
  @tracked selectedPairKeys = new Map();

  constructor() {
    super(...arguments);
    this.load();
  }

  async load() {
    try {
      this.data = await ajax("/admin/config/design-wizard.json");

      const defaultTheme =
        this.data.themes.find((theme) => theme.default) ??
        this.data.themes.find((theme) => theme.id === HORIZON_THEME_ID);
      this.themeId = defaultTheme.id;
      this.selectedPairKeys = new Map(
        this.data.themes.map((theme) => [theme.id, this.currentPairKey(theme)])
      );
      this.palettesUserSelectable = this.data.palettes_user_selectable;
      this.bodyFont = this.data.base_font;
      this.headingFont = this.data.heading_font;
      this.homepage =
        this.data.homepage === "categories" ? "categories" : "latest";
      this.categoryPageStyle = this.siteSettings.desktop_category_page_style;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  currentPairKey(theme) {
    const pair = theme.palette_pairs.find(
      (candidate) =>
        (theme.color_scheme_id &&
          candidate.light?.id === theme.color_scheme_id) ||
        (theme.dark_color_scheme_id &&
          candidate.dark?.id === theme.dark_color_scheme_id)
    );
    return (pair ?? theme.palette_pairs[0])?.key;
  }

  get selectedTheme() {
    return this.data.themes.find((theme) => theme.id === this.themeId);
  }

  get pairs() {
    return this.selectedTheme?.palette_pairs ?? [];
  }

  get selectedPair() {
    const key = this.selectedPairKeys.get(this.themeId);
    return this.pairs.find((pair) => pair.key === key) ?? this.pairs[0];
  }

  get effectiveColorMode() {
    return this.selectedPair?.dark_only ? "dark" : this.colorMode;
  }

  get previewPalette() {
    const pair = this.selectedPair;
    if (!pair) {
      return;
    }
    return this.effectiveColorMode === "dark"
      ? (pair.dark ?? pair.light)
      : (pair.light ?? pair.dark);
  }

  get colorsSummary() {
    const mode = i18n(
      `admin_onboarding_banner.design_wizard.colors.${this.effectiveColorMode}`
    );
    return `${this.selectedPair?.name} · ${mode}`;
  }

  get fontsSummary() {
    const fontName = (key) =>
      key?.replaceAll("_", " ").replace(/\b\w/g, (c) => c.toUpperCase());
    if (this.bodyFont === this.headingFont) {
      return fontName(this.bodyFont);
    }
    return `${fontName(this.bodyFont)} / ${fontName(this.headingFont)}`;
  }

  get homepageSummary() {
    return i18n(
      `admin_onboarding_banner.design_wizard.homepage.${
        this.homepage === "categories" ? "categories" : "topic_list"
      }`
    );
  }

  @action
  toggleSection(sectionId) {
    this.openSection = this.openSection === sectionId ? null : sectionId;
  }

  @action
  selectTheme(themeId) {
    this.themeId = themeId;
  }

  @action
  selectPair(pairKey) {
    this.selectedPairKeys = new Map(this.selectedPairKeys).set(
      this.themeId,
      pairKey
    );
  }

  @action
  selectColorMode(mode) {
    this.colorMode = mode;
  }

  @action
  toggleUserSelectable() {
    this.palettesUserSelectable = !this.palettesUserSelectable;
  }

  @action
  selectBodyFont(fontKey) {
    this.bodyFont = fontKey;
  }

  @action
  selectHeadingFont(fontKey) {
    this.headingFont = fontKey;
  }

  @action
  selectHomepage(homepage) {
    this.homepage = homepage;
  }

  @action
  selectCategoryPageStyle(value) {
    this.categoryPageStyle = value;
  }

  @action
  async save() {
    this.saving = true;

    try {
      await ajax("/admin/config/design-wizard.json", {
        type: "PUT",
        data: {
          theme_id: this.themeId,
          light_palette_id: this.selectedPair?.light?.id,
          dark_palette_id: this.selectedPair?.dark?.id,
          palettes_user_selectable: this.palettesUserSelectable,
          base_font: this.bodyFont,
          heading_font: this.headingFont,
          homepage: this.homepage,
          category_page_style:
            this.homepage === "categories" ? this.categoryPageStyle : null,
        },
      });

      setLocalTheme([], 0);

      await this.args.model?.onThemeSelected?.();
      window.location.reload();
    } catch (error) {
      this.saving = false;
      popupAjaxError(error);
    }
  }

  <template>
    <DModal
      class="design-wizard-modal --max"
      @title={{i18n "admin_onboarding_banner.design_wizard.title"}}
      @subtitle={{i18n "admin_onboarding_banner.design_wizard.subtitle"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <DConditionalLoadingSpinner @condition={{this.loading}}>
          {{#if this.data}}
            <div class="design-wizard-modal__layout">
              <div class="design-wizard-modal__rail">
                <Section
                  @id="theme"
                  @title={{i18n
                    "admin_onboarding_banner.design_wizard.sections.theme"
                  }}
                  @summary={{this.selectedTheme.name}}
                  @open={{eq this.openSection "theme"}}
                  @onToggle={{this.toggleSection}}
                >
                  <ThemeSection
                    @themes={{this.data.themes}}
                    @currentTheme={{this.data.current_theme}}
                    @selectedThemeId={{this.themeId}}
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
                    @pairs={{this.pairs}}
                    @selectedPairKey={{this.selectedPair.key}}
                    @selectedPairName={{this.selectedPair.name}}
                    @colorMode={{this.effectiveColorMode}}
                    @darkOnly={{this.selectedPair.dark_only}}
                    @userSelectable={{this.palettesUserSelectable}}
                    @onSelectPair={{this.selectPair}}
                    @onSelectMode={{this.selectColorMode}}
                    @onToggleUserSelectable={{this.toggleUserSelectable}}
                  />
                </Section>

                <Section
                  @id="fonts"
                  @title={{i18n
                    "admin_onboarding_banner.design_wizard.sections.fonts"
                  }}
                  @summary={{this.fontsSummary}}
                  @open={{eq this.openSection "fonts"}}
                  @onToggle={{this.toggleSection}}
                >
                  <FontsSection
                    @bodyFont={{this.bodyFont}}
                    @headingFont={{this.headingFont}}
                    @onSelectBodyFont={{this.selectBodyFont}}
                    @onSelectHeadingFont={{this.selectHeadingFont}}
                  />
                </Section>

                <Section
                  @id="homepage"
                  @title={{i18n
                    "admin_onboarding_banner.design_wizard.sections.homepage"
                  }}
                  @summary={{this.homepageSummary}}
                  @open={{eq this.openSection "homepage"}}
                  @onToggle={{this.toggleSection}}
                >
                  <HomepageSection
                    @homepage={{this.homepage}}
                    @categoryPageStyle={{this.categoryPageStyle}}
                    @categoryPageStyles={{this.data.category_page_styles}}
                    @onSelectHomepage={{this.selectHomepage}}
                    @onSelectCategoryPageStyle={{this.selectCategoryPageStyle}}
                  />
                </Section>
              </div>

              <PreviewPane
                @palette={{this.previewPalette}}
                @themeId={{this.themeId}}
                @bodyFont={{this.bodyFont}}
                @headingFont={{this.headingFont}}
                @homepage={{this.homepage}}
                @categoryPageStyle={{this.categoryPageStyle}}
                @userSelectable={{this.palettesUserSelectable}}
              />
            </div>
          {{/if}}
        </DConditionalLoadingSpinner>
      </:body>
      <:footer>
        <DButton
          @action={{this.save}}
          @label="admin_onboarding_banner.design_wizard.save"
          @disabled={{this.loading}}
          @isLoading={{this.saving}}
          class="btn-primary design-wizard-modal__save"
        />
        <DButton
          @action={{@closeModal}}
          @label="admin_onboarding_banner.design_wizard.skip"
          class="btn-flat design-wizard-modal__skip"
        />
      </:footer>
    </DModal>
  </template>
}
