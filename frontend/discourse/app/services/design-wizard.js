import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { applyColorScheme } from "discourse/admin/lib/color-scheme-manager";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  applyPreviewFonts,
  clearPreview,
} from "discourse/lib/design-wizard-preview";
import { isTesting } from "discourse/lib/environment";
import getURL from "discourse/lib/get-url";
import discourseLater from "discourse/lib/later";
import { HORIZON_THEME_ID, setLocalTheme } from "discourse/lib/theme-selector";
import DiscourseURL from "discourse/lib/url";

const STATE_KEY = "design_wizard_sidebar_state";
// px equivalents of the base-font-size variables, used to size the wizard
// chrome absolutely so text size previews cannot resize it
const TEXT_SIZE_PX = {
  smallest: "13px",
  smaller: "14px",
  normal: "16px",
  larger: "18px",
  largest: "20px",
};
// the stylesheet endpoint falls back to the base light palette for unknown
// ids, which is exactly what a theme without an assigned palette renders
const BASE_LIGHT_PALETTE_ID = -1;
// mirrors the onboarding step's own completion key so a wizard finished
// after a theme-preview reload (where the step's callback is gone) still
// marks the step complete
const STEP_COMPLETED_KEY = "onboarding_step_select_theme";

/**
 * Drives the sidebar variant of the design wizard: the sidebar is taken
 * over by customization controls while the current page acts as the live
 * preview. Selections only touch the page's color/font variables; nothing
 * is persisted until save.
 */
export default class DesignWizardService extends Service {
  @service keyValueStore;
  @service router;
  @service siteSettings;

  @tracked active = false;
  @tracked data;
  @tracked themeId;
  @tracked colorMode = "light";
  @tracked palettesUserSelectable = false;
  @tracked bodyFont;
  @tracked headingFont;
  @tracked homepage;
  @tracked categoryPageStyle;
  @tracked saving = false;
  @tracked selectedPairKeys = new Map();
  @tracked stepIndex = 0;
  // resuming an in-progress wizard (e.g. after a theme-preview reload)
  // should not replay the sheet's entrance animation
  @tracked animateEntrance = true;

  #onComplete;
  #originalCategoryPageStyle;

  async start({ onComplete } = {}) {
    this.#onComplete = onComplete;
    this.#originalCategoryPageStyle ??=
      this.siteSettings.desktop_category_page_style;

    // always fetch fresh: progress saves change the settings this payload
    // reflects, so a cached copy would preview stale selections
    try {
      this.data = await ajax("/admin/config/design-wizard.json");
    } catch (error) {
      popupAjaxError(error);
      return;
    }

    const stored = this.#storedState;
    if (stored) {
      this.#restore(stored);
    } else {
      this.#initFromData();
    }

    this.animateEntrance = !stored;
    this.active = true;
    this.#sizeChromeFromSettings();

    if (stored && this.homepage === "categories") {
      this.siteSettings.desktop_category_page_style = this.categoryPageStyle;
    }

    await this.#previewSelections();
  }

  resumeAfterThemePreview({ onComplete } = {}) {
    const previewThemeId = new URLSearchParams(window.location.search).get(
      "preview_theme_id"
    );
    if (!this.#storedState || previewThemeId === null) {
      return;
    }

    this.start({ onComplete });
  }

  get selectedTheme() {
    return this.data?.themes.find((theme) => theme.id === this.themeId);
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

  selectTheme(themeId) {
    if (themeId === this.themeId) {
      return;
    }

    this.themeId = themeId;
    this.#persistState();

    // a different theme is a different asset build, so previewing it means
    // reloading the page; state is restored from the store afterwards
    window.location.assign(
      getURL(`/?preview_theme_id=${encodeURIComponent(themeId)}`)
    );
  }

  async selectPair(pairKey) {
    this.selectedPairKeys = new Map(this.selectedPairKeys).set(
      this.themeId,
      pairKey
    );
    this.#persistState();
    await this.#previewSelections();
  }

  async selectColorMode(mode) {
    this.colorMode = mode;
    this.#persistState();
    await this.#previewSelections();
  }

  toggleUserSelectable() {
    this.palettesUserSelectable = !this.palettesUserSelectable;
    this.#persistState();
  }

  setStepIndex(stepIndex) {
    this.stepIndex = stepIndex;
    this.#persistState();
  }

  selectBodyFont(fontKey) {
    this.bodyFont = fontKey;
    this.#persistState();
    applyPreviewFonts(document, {
      bodyFont: this.bodyFont,
      headingFont: this.headingFont,
    });
  }

  selectHeadingFont(fontKey) {
    this.headingFont = fontKey;
    this.#persistState();
    applyPreviewFonts(document, {
      bodyFont: this.bodyFont,
      headingFont: this.headingFont,
    });
  }

  selectHomepage(homepage) {
    this.homepage = homepage;
    if (homepage === "categories") {
      this.categoryPageStyle = "categories_boxes";
      this.siteSettings.desktop_category_page_style = this.categoryPageStyle;
    }
    this.#persistState();

    // the page behind the sheet is the preview: show the chosen homepage.
    // Explicit paths, because "/" resolves to the currently saved default
    // homepage rather than the one being selected
    DiscourseURL.routeTo(getURL(`/${homepage}`));
  }

  selectCategoryPageStyle(value) {
    this.categoryPageStyle = value;
    this.#persistState();

    // the client copy of the setting drives how the categories page renders,
    // so mutating it and re-rendering previews the style live
    this.siteSettings.desktop_category_page_style = value;
    this.#refreshCategoriesPage();
  }

  stop() {
    this.active = false;
    this.keyValueStore.remove(STATE_KEY);
    clearPreview(document);

    if (this.#originalCategoryPageStyle) {
      this.siteSettings.desktop_category_page_style =
        this.#originalCategoryPageStyle;
      this.#refreshCategoriesPage();
    }
    document.documentElement.style.removeProperty(
      "--design-wizard-chrome-font-size"
    );

    if (this.#currentPreviewThemeId !== null) {
      window.location.assign(getURL("/"));
      return;
    }

    this.#revertPalette();
  }

  async save() {
    this.saving = true;

    try {
      await ajax("/admin/config/design-wizard.json", {
        type: "PUT",
        data: this.#selectionsPayload,
      });

      this.keyValueStore.remove(STATE_KEY);
      setLocalTheme([], 0);

      if (this.#onComplete) {
        await this.#onComplete();
      } else {
        this.keyValueStore.set({ key: STEP_COMPLETED_KEY, value: true });
      }

      window.location.assign(getURL("/"));
    } catch (error) {
      this.saving = false;
      popupAjaxError(error);
    }
  }

  // persists the selections made so far without finishing the wizard, so
  // closing mid-flow only discards the step being worked on
  async saveProgress() {
    this.saving = true;

    try {
      await ajax("/admin/config/design-wizard.json", {
        type: "PUT",
        data: this.#selectionsPayload,
      });

      // saving recompiles stylesheets and the live reloader swaps them in,
      // which can momentarily replace the previewed palette with the saved
      // theme's default; re-assert the preview now and once more after the
      // late-arriving swap
      await this.#previewSelections();
      if (!isTesting()) {
        discourseLater(() => {
          if (this.active) {
            this.#previewSelections();
          }
        }, 1000);
      }
      return true;
    } catch (error) {
      popupAjaxError(error);
      return false;
    } finally {
      this.saving = false;
    }
  }

  get #selectionsPayload() {
    return {
      theme_id: this.themeId,
      light_palette_id: this.selectedPair?.light?.id,
      dark_palette_id: this.selectedPair?.dark?.id,
      palettes_user_selectable: this.palettesUserSelectable,
      base_font: this.bodyFont,
      heading_font: this.headingFont,
      homepage: this.homepage,
      category_page_style:
        this.homepage === "categories" ? this.categoryPageStyle : null,
    };
  }

  get #storedState() {
    const raw = this.keyValueStore.get(STATE_KEY);
    if (!raw) {
      return;
    }

    try {
      return JSON.parse(raw);
    } catch {
      this.keyValueStore.remove(STATE_KEY);
    }
  }

  get #currentPreviewThemeId() {
    return new URLSearchParams(window.location.search).get("preview_theme_id");
  }

  #sizeChromeFromSettings() {
    const size = TEXT_SIZE_PX[this.siteSettings.default_text_size];
    if (size) {
      document.documentElement.style.setProperty(
        "--design-wizard-chrome-font-size",
        size
      );
    }
  }

  #initFromData() {
    const defaultTheme =
      this.data.themes.find((theme) => theme.default) ??
      this.data.themes.find((theme) => theme.id === HORIZON_THEME_ID);
    this.themeId = defaultTheme.id;
    this.selectedPairKeys = new Map(
      this.data.themes.map((theme) => [theme.id, this.#currentPairKey(theme)])
    );
    this.palettesUserSelectable = this.data.palettes_user_selectable;
    this.bodyFont = this.data.base_font;
    this.headingFont = this.data.heading_font;
    this.homepage = this.#supportedHomepage(this.data.homepage);
    this.categoryPageStyle = this.siteSettings.desktop_category_page_style;
    this.stepIndex = 0;
  }

  #restore(stored) {
    this.themeId = stored.themeId;
    this.selectedPairKeys = new Map(stored.selectedPairKeys);
    this.colorMode = stored.colorMode;
    this.palettesUserSelectable = stored.palettesUserSelectable;
    this.bodyFont = stored.bodyFont;
    this.headingFont = stored.headingFont;
    this.homepage =
      stored.homepage ?? this.#supportedHomepage(this.data.homepage);
    this.categoryPageStyle =
      stored.categoryPageStyle ?? this.siteSettings.desktop_category_page_style;
    this.stepIndex = stored.stepIndex ?? 0;
  }

  #persistState() {
    this.keyValueStore.set({
      key: STATE_KEY,
      value: JSON.stringify({
        themeId: this.themeId,
        selectedPairKeys: [...this.selectedPairKeys.entries()],
        colorMode: this.colorMode,
        palettesUserSelectable: this.palettesUserSelectable,
        bodyFont: this.bodyFont,
        headingFont: this.headingFont,
        homepage: this.homepage,
        categoryPageStyle: this.categoryPageStyle,
        stepIndex: this.stepIndex,
      }),
    });
  }

  #refreshCategoriesPage() {
    if (this.router.currentRouteName?.startsWith("discovery.categories")) {
      this.router.refresh();
    }
  }

  #supportedHomepage(homepage) {
    return ["latest", "top", "hot", "categories"].includes(homepage)
      ? homepage
      : "latest";
  }

  #currentPairKey(theme) {
    const pair = theme.palette_pairs.find(
      (candidate) =>
        (theme.color_scheme_id &&
          candidate.light?.id === theme.color_scheme_id) ||
        (theme.dark_color_scheme_id &&
          candidate.dark?.id === theme.dark_color_scheme_id)
    );
    return (pair ?? theme.palette_pairs[0])?.key;
  }

  async #previewSelections() {
    applyPreviewFonts(document, {
      bodyFont: this.bodyFont,
      headingFont: this.headingFont,
    });

    const paletteId = this.previewPalette?.id;
    if (paletteId) {
      try {
        await applyColorScheme(
          { id: paletteId },
          { replace: true, themeId: this.themeId }
        );
      } catch {
        // the manager already reports failures; a failed preview should not
        // break the wizard
      }
    }
  }

  async #revertPalette() {
    const renderedTheme = this.data?.themes.find((theme) => theme.default);

    try {
      await applyColorScheme(
        { id: renderedTheme?.color_scheme_id ?? BASE_LIGHT_PALETTE_ID },
        { replace: true }
      );
    } catch {
      // a failed revert only leaves the previewed colors in place
    }

    document
      .querySelectorAll("link[data-scheme-id]")
      .forEach((link) => link.removeAttribute("data-scheme-id"));
  }
}
