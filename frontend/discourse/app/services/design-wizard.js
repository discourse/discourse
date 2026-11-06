import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import {
  applyColorScheme,
  captureColorSchemeLinks,
  renderedColorMode,
  restoreColorSchemeLinks,
  showColorMode,
} from "discourse/admin/lib/color-scheme-manager";
import { logOnboardingEvent } from "discourse/lib/admin-onboarding";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  applyPreviewFonts,
  clearPreview,
} from "discourse/lib/design-wizard-preview";
import { isTesting } from "discourse/lib/environment";
import getURL from "discourse/lib/get-url";
import { homepagePreviewDestination } from "discourse/lib/homepage-router-overrides";
import discourseLater from "discourse/lib/later";
import { deepEqual } from "discourse/lib/object";
import { HORIZON_THEME_ID, setLocalTheme } from "discourse/lib/theme-selector";
import DiscourseURL from "discourse/lib/url";

const STATE_KEY = "design_wizard_panel_state";
// site settings the wizard mutates locally to preview a selection, and which
// have to be put back when the wizard is closed without saving
const PREVIEWED_SITE_SETTINGS = [
  "desktop_category_page_style",
  "site_logo_url",
];
const SELECT_THEME_STEP = "select_theme";
const SUPPORTED_HOMEPAGES = ["latest", "categories"];
// the wizard as the first stop of admin onboarding, versus an admin running it
// again later from the admin interface
export const SOURCE_ONBOARDING = "onboarding";
export const SOURCE_ADMIN = "admin";
// launches the wizard on load, so it can be reached by URL from anywhere
export const DESIGN_WIZARD_PARAM = "design_wizard";
// which color modes the site offers; a single mode's palette is used for both
export const PALETTE_MODES = Object.freeze({
  both: "both",
  light: "light",
  dark: "dark",
});
// mirrors the onboarding step's own completion key so a wizard finished
// after its caller was torn down still marks the step complete
const STEP_COMPLETED_KEY = `onboarding_step_${SELECT_THEME_STEP}`;

/**
 * Drives the design wizard panel while the current page acts as the live
 * preview. Each completed step is persisted so the flow can survive the theme
 * preview reloads required by a different asset build.
 */
export default class DesignWizardService extends Service {
  @service capabilities;
  @service keyValueStore;
  @service router;
  @service siteSettings;

  @tracked active = false;
  @tracked minimized = false;
  @tracked data;
  @tracked themeId;
  @tracked colorMode = "light";
  @tracked palettesUserSelectable = false;
  @tracked bodyFont;
  @tracked headingFont;
  @tracked homepage;
  @tracked homepageSettings;
  @tracked categoryPageStyle;
  @tracked logo;
  @tracked saving = false;
  // a theme preview replaces the whole page, so the panel stays busy until it does
  @tracked applyingTheme = false;
  // theme id => { mode, light, dark }: the PALETTE_MODES value and each row's
  // pair key, kept while a row is hidden so switching back restores it
  @tracked paletteSelections = new Map();
  @tracked stepIndex = 0;
  // resuming an in-progress wizard (e.g. after a theme-preview reload)
  // should not replay the sheet's entrance animation
  @tracked animateEntrance = true;
  @tracked source = SOURCE_ONBOARDING;
  @tracked returnUrl;
  // whether a step has been saved, i.e. whether the live site has changed yet
  @tracked progressSaved = false;

  #onComplete;
  #snapshot;
  #starting = false;
  #startFailed = false;
  #originalSiteSettings;
  #originalHomepageSettings;
  #originalColorSchemeLinks;
  #prefetched = false;
  // what the server holds, so a step save only writes choices that differ from it
  #savedSelections;
  // until the admin or a theme switch picks one, the shown homepage may only be
  // the fallback for one the wizard can't offer, which must not be saved
  #homepageChosen = false;

  // with room for both, the page reflows beside the panel instead of under it
  get docked() {
    return this.active && this.capabilities.viewport.xl;
  }

  get selectedTheme() {
    return this.data?.themes.find((theme) => theme.id === this.themeId);
  }

  get additionalHomepages() {
    return this.data?.additional_homepages ?? [];
  }

  get #supportedHomepages() {
    return [
      ...SUPPORTED_HOMEPAGES,
      ...this.additionalHomepages.map(({ id }) => id),
    ];
  }

  get #restorableHomepages() {
    return [
      ...this.#supportedHomepages,
      ...(this.data?.restorable_homepages ?? []),
    ];
  }

  get pairs() {
    return this.selectedTheme?.palette_pairs ?? [];
  }

  get lightPairs() {
    return this.pairs.filter((pair) => pair.light);
  }

  get darkPairs() {
    return this.pairs.filter((pair) => pair.dark);
  }

  get selectedLightPair() {
    return this.#selectedPair(this.lightPairs, "light");
  }

  get selectedDarkPair() {
    return this.#selectedPair(this.darkPairs, "dark");
  }

  get paletteMode() {
    return this.paletteSelections.get(this.themeId)?.mode ?? PALETTE_MODES.both;
  }

  get showsLightPalettes() {
    return this.paletteMode !== PALETTE_MODES.dark;
  }

  get showsDarkPalettes() {
    return this.paletteMode !== PALETTE_MODES.light;
  }

  get effectiveColorMode() {
    return this.paletteMode === PALETTE_MODES.both
      ? this.colorMode
      : this.paletteMode;
  }

  get #lightPalette() {
    return this.showsLightPalettes
      ? this.selectedLightPair?.light
      : this.selectedDarkPair?.dark;
  }

  get #darkPalette() {
    return this.showsDarkPalettes
      ? this.selectedDarkPair?.dark
      : this.selectedLightPair?.light;
  }

  get previewPalette() {
    return this.effectiveColorMode === "dark"
      ? this.#darkPalette
      : this.#lightPalette;
  }

  // Only themes offered by the wizard can be restored through its endpoint.
  get canRevert() {
    return (
      this.source === SOURCE_ADMIN && this.progressSaved && !!this.#snapshot
    );
  }

  // closing a run that changed the live site is a decision, even when the
  // change cannot be undone from here
  get needsCloseConfirmation() {
    return this.source === SOURCE_ADMIN && this.progressSaved;
  }

  get #selectionsPayload() {
    return {
      theme_id: this.themeId,
      light_palette_id: this.#lightPalette?.id,
      // a light-only site has no dark palette
      dark_palette_id: this.showsDarkPalettes
        ? this.selectedDarkPair?.dark?.id
        : undefined,
      palettes_user_selectable: this.palettesUserSelectable,
      base_font: this.bodyFont,
      heading_font: this.headingFont,
      category_page_style:
        this.homepage === "categories" ? this.categoryPageStyle : null,
      // untouched choices are left alone rather than written back every step,
      // so a homepage the wizard can't offer isn't replaced by its fallback
      ...(this.#homepageChanged
        ? { homepage: this.homepage, homepage_settings: this.homepageSettings }
        : {}),
      ...(this.#logoChanged ? { logo: this.logo } : {}),
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

  get #homepageChanged() {
    return (
      this.#homepageChosen &&
      (this.homepage !== this.#savedSelections.homepage ||
        !deepEqual(
          this.homepageSettings ?? {},
          this.#savedSelections.homepageSettings
        ))
    );
  }

  get #logoChanged() {
    return (this.logo ?? "") !== this.#savedSelections.logo;
  }

  // warms the browser cache for the theme screenshots, which dominate the
  // panel's first paint on a slow connection
  async prefetch() {
    if (this.#prefetched || this.active || isTesting()) {
      return;
    }
    this.#prefetched = true;

    try {
      const data = await ajax("/admin/config/design-wizard.json");
      for (const theme of data.themes) {
        for (const url of [
          theme.screenshot_light_url,
          theme.screenshot_dark_url,
        ]) {
          if (url) {
            new Image().src = url;
          }
        }
      }
    } catch {
      // a failed warm-up is not worth surfacing, `start` reports its own errors
    }
  }

  async start({
    onComplete,
    source = SOURCE_ONBOARDING,
    returnUrl,
    resuming = false,
  } = {}) {
    this.#onComplete = onComplete;
    this.#starting = true;
    this.#startFailed = false;
    this.#originalSiteSettings ??= Object.fromEntries(
      PREVIEWED_SITE_SETTINGS.map((name) => [name, this.siteSettings[name]])
    );

    // always fetch fresh: progress saves change the settings this payload
    // reflects, so a cached copy would preview stale selections
    try {
      this.data = await ajax("/admin/config/design-wizard.json");
    } catch (error) {
      this.#starting = false;
      this.#startFailed = true;
      popupAjaxError(error);
      return;
    }

    // stored state describes the run the theme preview interrupted; a run
    // started from anywhere else is a new one and must not inherit it
    const stored = resuming ? this.#storedState : null;
    if (stored) {
      this.#restore(stored);
    } else {
      this.keyValueStore.remove(STATE_KEY);
      this.source = source;
      this.returnUrl = returnUrl;
      this.progressSaved = false;
      this.#initFromData();
      this.#snapshot = this.#buildSnapshot();
      // the source, the page to return to and the snapshot all have to outlive
      // the reload a theme preview performs
      this.#persistState();
    }

    this.animateEntrance = !stored;
    this.active = true;
    this.#starting = false;
    this.#originalColorSchemeLinks = captureColorSchemeLinks();

    this.#previewSiteSettings();
    await this.#previewSelections();
  }

  // entry point for an admin re-running the wizard: the page behind the sheet
  // is the preview, so the flow has to move to the forum before it opens
  async launch({ returnUrl } = {}) {
    if (this.active || this.#starting) {
      return;
    }

    await this.router.transitionTo(homepagePreviewDestination());
    await this.start({ source: SOURCE_ADMIN, returnUrl });
  }

  // lets `save` fall back to the store instead of reaching into a caller that
  // was torn down while the sheet stayed open
  clearCompletionCallback(callback) {
    if (callback === undefined || this.#onComplete === callback) {
      this.#onComplete = undefined;
    }
  }

  resumeAfterThemePreview({ onComplete } = {}) {
    // the caller can remount while the sheet is open (the onboarding banner
    // renders per-route); an active or opening wizard has nothing to resume,
    // only the completion callback needs to point at the fresh caller
    if (this.active || this.#starting) {
      this.#onComplete = onComplete;
      return;
    }

    if (this.#startFailed) {
      return;
    }

    const previewThemeId = new URLSearchParams(window.location.search).get(
      "preview_theme_id"
    );
    const stored = this.#storedState;
    // a preview of some other theme is somebody else's link, not this run
    if (!stored || String(stored.themeId) !== previewThemeId) {
      return;
    }

    this.start({ onComplete, resuming: true });
  }

  async selectTheme(themeId) {
    if (themeId === this.themeId || this.applyingTheme) {
      return;
    }

    this.applyingTheme = true;
    const previousThemeId = this.themeId;
    const theme = this.data.themes.find(
      (candidate) => candidate.id === themeId
    );
    this.themeId = themeId;

    if (theme?.remote_url) {
      try {
        const result = await ajax("/admin/themes/import", {
          type: "POST",
          data: { remote: theme.remote_url },
        });
        if (!this.active) {
          this.applyingTheme = false;
          return;
        }
        themeId = result.theme.id;
        this.themeId = themeId;
      } catch (error) {
        this.themeId = previousThemeId;
        this.applyingTheme = false;
        popupAjaxError(error);
        return;
      }
    }

    const themeHomepage = theme?.default_homepage;
    let previewPath = "/";

    if (this.#supportedHomepages.includes(themeHomepage)) {
      const homepage = themeHomepage;
      const homepageOption = this.additionalHomepages.find(
        ({ id }) => id === homepage
      );

      this.homepage = homepage;
      this.#homepageChosen = true;
      this.homepageSettings = {
        ...this.#originalHomepageSettings,
        ...homepageOption?.settings,
      };
      previewPath = homepageOption?.path ?? `/${homepage}`;
    }
    this.#persistState();

    // a different theme is a different asset build, so previewing it means
    // reloading the page; state is restored from the store afterwards
    this.#navigateToThemePreview(themeId, previewPath);
  }

  /**
   * Selects the palette pair used for one color mode, and previews that mode.
   *
   * @param {"light" | "dark"} mode
   * @param {string} pairKey
   */
  async selectPalette(mode, pairKey) {
    this.#updatePaletteSelection({ [mode]: pairKey });
    this.colorMode = mode;
    this.#persistState();
    await this.#previewSelections();
  }

  /**
   * Selects which color modes the site offers.
   *
   * @param {string} paletteMode - a PALETTE_MODES value
   */
  async selectPaletteMode(paletteMode) {
    this.#updatePaletteSelection({ mode: paletteMode });
    this.#persistState();
    await this.#previewSelections();
  }

  setMinimized(minimized) {
    this.minimized = minimized;
    this.animateEntrance = false;
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
    this.#homepageChosen = true;
    const additionalHomepage = this.additionalHomepages.find(
      ({ id }) => id === homepage
    );
    this.homepageSettings = {
      ...this.#originalHomepageSettings,
      ...additionalHomepage?.settings,
    };
    if (homepage === "categories") {
      this.categoryPageStyle = "categories_boxes";
      this.siteSettings.desktop_category_page_style = this.categoryPageStyle;
    }
    this.#persistState();

    // An explicit destination previews unsaved choices without reloading the wizard.
    this.router.transitionTo(
      additionalHomepage?.path ?? `discovery.${homepage}`
    );
  }

  selectCategoryPageStyle(value) {
    this.categoryPageStyle = value;
    this.#persistState();

    // the client copy of the setting drives how the categories page renders,
    // so mutating it and re-rendering previews the style live
    this.siteSettings.desktop_category_page_style = value;
    this.#refreshCategoriesPage();
  }

  /**
   * Selects the site logo and previews it in the header.
   *
   * @param {{ url: string } | null} upload - null removes the logo
   */
  selectLogo(upload) {
    this.logo = upload ? getURL(upload.url) : "";
    this.siteSettings.site_logo_url = this.logo;
    this.#persistState();
  }

  stop() {
    const { returnUrl, progressSaved } = this;
    const previewingTheme = this.#currentPreviewThemeId !== null;
    const returnsToAdmin = this.source === SOURCE_ADMIN && !!returnUrl;

    this.active = false;
    this.#onComplete = undefined;
    this.keyValueStore.remove(STATE_KEY);
    clearPreview(document);

    if (this.#originalSiteSettings) {
      for (const [name, value] of Object.entries(this.#originalSiteSettings)) {
        this.siteSettings[name] = value;
      }
      this.#refreshCategoriesPage();
    }
    restoreColorSchemeLinks(this.#originalColorSchemeLinks);
    this.#reset();

    // a saved step or a previewed theme means the page is rendering something
    // other than what the site is now, so returning to admin needs a full load
    if (previewingTheme || (returnsToAdmin && progressSaved)) {
      DiscourseURL.redirectTo(returnsToAdmin ? returnUrl : "/");
    } else if (returnsToAdmin) {
      this.router.transitionTo(returnUrl);
    }
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

      // a re-run is not part of onboarding and must not report progress on it
      if (this.source === SOURCE_ONBOARDING) {
        if (this.#onComplete) {
          await this.#onComplete();
        } else {
          await this.#completeStepWithoutCaller();
        }
      }

      this.#leave();
    } catch (error) {
      this.saving = false;
      popupAjaxError(error);
    }
  }

  // puts the site back the way it was when this run started, for an admin who
  // explored the wizard on a live site and decided against the result
  async revert() {
    if (!this.canRevert) {
      return;
    }

    this.saving = true;

    try {
      await ajax("/admin/config/design-wizard.json", {
        type: "PUT",
        data: this.#snapshot,
      });

      this.keyValueStore.remove(STATE_KEY);
      setLocalTheme([], 0);
      this.#leave();
    } catch (error) {
      this.saving = false;
      popupAjaxError(error);
    }
  }

  // persists the selections made so far without finishing the wizard, so
  // closing mid-flow only discards the step being worked on
  async saveProgress() {
    this.saving = true;

    const payload = this.#selectionsPayload;

    try {
      await ajax("/admin/config/design-wizard.json", {
        type: "PUT",
        data: payload,
      });

      this.#recordSavedSelections(payload);
      this.progressSaved = true;
      this.#persistState();

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

  // the durable half of the step's own markAsCompleted, for when the caller is
  // gone; awaited so the reload can't cancel the audit write in flight
  async #completeStepWithoutCaller() {
    const alreadyCompleted = !!this.keyValueStore.get(STEP_COMPLETED_KEY);
    this.keyValueStore.set({ key: STEP_COMPLETED_KEY, value: true });

    if (!alreadyCompleted) {
      await logOnboardingEvent("step_completed", SELECT_THEME_STEP);
    }
  }

  // a full load, so what renders afterwards is the saved site rather than the
  // preview the sheet was showing
  #leave() {
    DiscourseURL.redirectTo(this.returnUrl || "/");
  }

  #reset() {
    this.minimized = false;
    this.source = SOURCE_ONBOARDING;
    this.returnUrl = undefined;
    this.progressSaved = false;
    this.#snapshot = undefined;
    this.#originalSiteSettings = undefined;
    this.#originalHomepageSettings = undefined;
    this.#savedSelections = undefined;
    this.#homepageChosen = false;
  }

  // captured before anything is previewed or saved, from the values the server
  // reported, so a revert restores the site rather than the preview
  #buildSnapshot() {
    const currentTheme = this.data.themes.find((theme) => theme.default);
    if (!currentTheme) {
      return;
    }

    const settings = this.#originalSiteSettings ?? this.siteSettings;

    return {
      theme_id: currentTheme.id,
      light_palette_id: currentTheme.color_scheme_id,
      dark_palette_id: currentTheme.dark_color_scheme_id,
      palettes_user_selectable: this.data.palettes_user_selectable,
      base_font: this.data.base_font,
      heading_font: this.data.heading_font,
      // one the site can no longer use is left alone rather than failing the revert
      homepage: this.#restorableHomepages.includes(this.data.homepage)
        ? this.data.homepage
        : null,
      homepage_settings: this.data.homepage_settings,
      category_page_style: settings.desktop_category_page_style,
      logo: this.siteSettings.logo ?? "",
    };
  }

  #initFromData() {
    this.minimized = false;
    // a custom default theme isn't offered by the wizard, so nothing is
    // preselected and the page keeps rendering it until a theme is chosen
    const preselectedTheme =
      this.data.themes.find((theme) => theme.default) ??
      (this.data.current_theme
        ? null
        : this.data.themes.find((theme) => theme.id === HORIZON_THEME_ID));
    this.themeId = preselectedTheme?.id ?? null;
    this.paletteSelections = new Map(
      this.data.themes.map((theme) => [
        theme.id,
        this.#currentPaletteSelection(theme),
      ])
    );
    this.palettesUserSelectable = this.data.palettes_user_selectable;
    this.bodyFont = this.data.base_font;
    this.headingFont = this.data.heading_font;
    this.colorMode = renderedColorMode();
    this.homepage = this.#supportedHomepage(this.data.homepage);
    this.#homepageChosen = false;
    this.#originalHomepageSettings = this.data.homepage_settings ?? {};
    this.homepageSettings = this.#originalHomepageSettings;
    this.categoryPageStyle = this.siteSettings.desktop_category_page_style;
    this.logo = this.siteSettings.logo;
    this.#initSavedSelections();
    this.stepIndex = 0;
  }

  #restore(stored) {
    this.minimized = stored.minimized ?? false;
    this.source = stored.source ?? SOURCE_ONBOARDING;
    this.returnUrl = stored.returnUrl;
    this.progressSaved = stored.progressSaved ?? false;
    this.#snapshot = stored.snapshot;
    if (this.#snapshot) {
      this.#snapshot.homepage_settings = this.#availableHomepageSettings(
        this.#snapshot.homepage_settings
      );
      if (!this.#restorableHomepages.includes(this.#snapshot.homepage)) {
        this.#snapshot.homepage = null;
      }
    }
    this.#originalHomepageSettings = this.#availableHomepageSettings(
      stored.originalHomepageSettings ??
        stored.snapshot?.homepage_settings ??
        this.data.homepage_settings
    );
    this.themeId = stored.themeId;
    this.paletteSelections = new Map(stored.paletteSelections);
    this.colorMode = stored.colorMode ?? renderedColorMode();
    this.palettesUserSelectable = stored.palettesUserSelectable;
    this.bodyFont = stored.bodyFont;
    this.headingFont = stored.headingFont;
    this.homepage = this.#supportedHomepage(
      stored.homepage ?? this.data.homepage
    );
    this.#homepageChosen = stored.homepageChosen ?? false;
    this.homepageSettings = this.#availableHomepageSettings(
      stored.homepageSettings ?? this.data.homepage_settings
    );
    this.categoryPageStyle =
      stored.categoryPageStyle ?? this.siteSettings.desktop_category_page_style;
    this.logo = stored.logo ?? this.siteSettings.logo;
    this.#initSavedSelections();
    // selections are restored but the flow always restarts from the first
    // step, so a resumed wizard walks the same path as a fresh one
    this.stepIndex = 0;
  }

  // `data` is fetched fresh on every start and the client copy of `logo` is
  // never previewed, so both reflect what the server holds
  #initSavedSelections() {
    this.#savedSelections = {
      homepage: this.data.homepage,
      homepageSettings: this.#availableHomepageSettings(
        this.data.homepage_settings
      ),
      logo: this.siteSettings.logo ?? "",
    };
  }

  #recordSavedSelections(payload) {
    if ("homepage" in payload) {
      this.#savedSelections.homepage = payload.homepage;
      this.#savedSelections.homepageSettings = payload.homepage_settings ?? {};
    }
    if ("logo" in payload) {
      this.#savedSelections.logo = payload.logo;
    }
  }

  #availableHomepageSettings(settings) {
    // A preview reload can resume after the available homepage options changed.
    return Object.fromEntries(
      Object.entries(settings ?? {}).filter(([name]) =>
        Object.hasOwn(this.data.homepage_settings ?? {}, name)
      )
    );
  }

  #persistState() {
    this.keyValueStore.set({
      key: STATE_KEY,
      value: JSON.stringify({
        minimized: this.minimized,
        themeId: this.themeId,
        paletteSelections: [...this.paletteSelections.entries()],
        colorMode: this.colorMode,
        palettesUserSelectable: this.palettesUserSelectable,
        bodyFont: this.bodyFont,
        headingFont: this.headingFont,
        homepage: this.homepage,
        homepageChosen: this.#homepageChosen,
        homepageSettings: this.homepageSettings,
        originalHomepageSettings: this.#originalHomepageSettings,
        categoryPageStyle: this.categoryPageStyle,
        logo: this.logo,
        source: this.source,
        returnUrl: this.returnUrl,
        progressSaved: this.progressSaved,
        snapshot: this.#snapshot,
      }),
    });
  }

  // the page behind the sheet renders from the client copy of these settings,
  // so assigning them previews the restored selections live
  #previewSiteSettings() {
    if (this.homepage === "categories") {
      this.siteSettings.desktop_category_page_style = this.categoryPageStyle;
    }
    if (this.#logoChanged) {
      this.siteSettings.site_logo_url = this.logo;
    }
  }

  #refreshCategoriesPage() {
    if (this.router.currentRouteName?.startsWith("discovery.categories")) {
      this.router.refresh();
    }
  }

  #navigateToThemePreview(themeId, path = "/") {
    DiscourseURL.redirectTo(
      `${path}?preview_theme_id=${encodeURIComponent(themeId)}`
    );
  }

  #supportedHomepage(homepage) {
    return this.#supportedHomepages.includes(homepage) ? homepage : "latest";
  }

  #updatePaletteSelection(changes) {
    this.paletteSelections = new Map(this.paletteSelections).set(this.themeId, {
      ...this.paletteSelections.get(this.themeId),
      ...changes,
    });
  }

  #selectedPair(pairs, mode) {
    const key = this.paletteSelections.get(this.themeId)?.[mode];
    return pairs.find((pair) => pair.key === key) ?? pairs[0];
  }

  // A key left undefined falls back to the row's first palette, which is also
  // what a theme without an assigned light palette renders. A theme without a
  // dark palette renders light-only, and one using its dark palette for both
  // modes renders dark-only.
  #currentPaletteSelection(theme) {
    const pairs = theme.palette_pairs ?? [];
    const darkId = theme.dark_color_scheme_id;
    const dark = darkId && pairs.find((pair) => pair.dark?.id === darkId)?.key;
    const light = pairs.find(
      (pair) =>
        theme.color_scheme_id && pair.light?.id === theme.color_scheme_id
    )?.key;

    let mode = PALETTE_MODES.both;
    if (!darkId) {
      mode = PALETTE_MODES.light;
    } else if (dark && theme.color_scheme_id === darkId) {
      mode = PALETTE_MODES.dark;
    }

    return { mode, light, dark };
  }

  async #previewSelections() {
    applyPreviewFonts(document, {
      bodyFont: this.bodyFont,
      headingFont: this.headingFont,
    });

    const mode = this.effectiveColorMode;
    const paletteId = this.previewPalette?.id;
    if (paletteId) {
      try {
        await applyColorScheme(
          { id: paletteId },
          { replace: true, themeId: this.themeId, mode }
        );
      } catch {
        // the manager already reports failures; a failed preview should not
        // break the wizard
      }
    }

    showColorMode(mode);
  }
}
