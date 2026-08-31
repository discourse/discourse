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
import { homepagePreviewDestination } from "discourse/lib/homepage-router-overrides";
import discourseLater from "discourse/lib/later";
import { HORIZON_THEME_ID, setLocalTheme } from "discourse/lib/theme-selector";
import DiscourseURL from "discourse/lib/url";

const STATE_KEY = "design_wizard_panel_state";
// site settings the wizard mutates locally to preview a selection, and which
// have to be put back when the wizard is closed without saving
const PREVIEWED_SITE_SETTINGS = [
  "desktop_category_page_style",
  "enable_welcome_banner",
  "welcome_banner_location",
  "search_experience",
];
const SELECT_THEME_STEP = "select_theme";
const SUPPORTED_HOMEPAGES = ["latest", "new", "hot", "categories"];
// the wizard as the first stop of admin onboarding, versus an admin running it
// again later from the admin interface
export const SOURCE_ONBOARDING = "onboarding";
export const SOURCE_ADMIN = "admin";
// launches the wizard on load, so it can be reached by URL from anywhere
export const DESIGN_WIZARD_PARAM = "design_wizard";
// mirrors the onboarding step's own completion key so a wizard finished
// after its caller was torn down still marks the step complete
const STEP_COMPLETED_KEY = `onboarding_step_${SELECT_THEME_STEP}`;

/**
 * Drives the design wizard panel while the current page acts as the live
 * preview. Each completed step is persisted so the flow can survive the theme
 * preview reloads required by a different asset build.
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
  @tracked welcomeBanner;
  @tracked welcomeBannerLocation;
  @tracked searchExperience;
  @tracked saving = false;
  // a theme preview replaces the whole page, so the panel stays busy until it does
  @tracked applyingTheme = false;
  @tracked selectedPairKeys = new Map();
  @tracked stepIndex = 0;
  // resuming an in-progress wizard (e.g. after a theme-preview reload)
  // should not replay the sheet's entrance animation
  @tracked animateEntrance = true;
  @tracked source = SOURCE_ONBOARDING;
  @tracked returnUrl;
  // whether a step has been saved, i.e. whether the live site has changed yet
  @tracked progressSaved = false;
  @tracked showIntro = false;

  #onComplete;
  #snapshot;
  #starting = false;
  #startFailed = false;
  #originalSiteSettings;
  #originalColorSchemeLinks;
  #prefetched = false;

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
      // onboarding introduces the wizard itself; a re-run has to say what it is
      // about to change before it changes anything
      this.showIntro = source !== SOURCE_ONBOARDING;
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

  // the endpoint only accepts core themes, so a site whose default theme the
  // wizard cannot express is not offered a way back to it
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

  dismissIntro() {
    this.showIntro = false;
  }

  selectTheme(themeId) {
    if (themeId === this.themeId || this.applyingTheme) {
      return;
    }

    this.applyingTheme = true;
    this.themeId = themeId;
    // these are resolved per theme, so let the reloaded page re-seed them from
    // the theme being previewed rather than carrying the old theme's values
    this.welcomeBanner = undefined;
    this.searchExperience = undefined;
    this.#persistState();

    // a different theme is a different asset build, so previewing it means
    // reloading the page; state is restored from the store afterwards
    this.#navigateToThemePreview(themeId);
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
    // Explicit routes, because "/" resolves to the currently saved default
    // homepage, and a router transition (unlike DiscourseURL.routeTo) can
    // never escalate to a full page load, which would dismiss the sheet
    this.router.transitionTo(`discovery.${homepage}`);
  }

  selectCategoryPageStyle(value) {
    this.categoryPageStyle = value;
    this.#persistState();

    // the client copy of the setting drives how the categories page renders,
    // so mutating it and re-rendering previews the style live
    this.siteSettings.desktop_category_page_style = value;
    this.#refreshCategoriesPage();
  }

  selectWelcomeBanner(enabled) {
    this.welcomeBanner = enabled;
    this.siteSettings.enable_welcome_banner = enabled;
    this.#persistState();
  }

  selectWelcomeBannerLocation(location) {
    this.welcomeBannerLocation = location;
    this.siteSettings.welcome_banner_location = location;
    this.#persistState();
  }

  selectSearchExperience(experience) {
    this.searchExperience = experience;
    this.siteSettings.search_experience = experience;
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

    try {
      await ajax("/admin/config/design-wizard.json", {
        type: "PUT",
        data: this.#selectionsPayload,
      });

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
    this.source = SOURCE_ONBOARDING;
    this.returnUrl = undefined;
    this.progressSaved = false;
    this.showIntro = false;
    this.#snapshot = undefined;
    this.#originalSiteSettings = undefined;
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
      // a homepage the wizard cannot express is left alone rather than replaced
      // with the one it fell back to
      homepage: SUPPORTED_HOMEPAGES.includes(this.data.homepage)
        ? this.data.homepage
        : null,
      category_page_style: settings.desktop_category_page_style,
      enable_welcome_banner: settings.enable_welcome_banner,
      welcome_banner_location: settings.welcome_banner_location,
      search_experience: settings.search_experience,
    };
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
      enable_welcome_banner: this.welcomeBanner,
      welcome_banner_location: this.welcomeBannerLocation,
      search_experience: this.searchExperience,
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

  #initFromData() {
    // a custom default theme isn't offered by the wizard, so nothing is
    // preselected and the page keeps rendering it until a theme is chosen
    const preselectedTheme =
      this.data.themes.find((theme) => theme.default) ??
      (this.data.current_theme
        ? null
        : this.data.themes.find((theme) => theme.id === HORIZON_THEME_ID));
    this.themeId = preselectedTheme?.id ?? null;
    this.selectedPairKeys = new Map(
      this.data.themes.map((theme) => [theme.id, this.#currentPairKey(theme)])
    );
    this.palettesUserSelectable = this.data.palettes_user_selectable;
    this.bodyFont = this.data.base_font;
    this.headingFont = this.data.heading_font;
    this.colorMode = renderedColorMode();
    this.homepage = this.#supportedHomepage(this.data.homepage);
    this.categoryPageStyle = this.siteSettings.desktop_category_page_style;
    this.welcomeBanner = this.siteSettings.enable_welcome_banner;
    this.welcomeBannerLocation = this.siteSettings.welcome_banner_location;
    this.searchExperience = this.siteSettings.search_experience;
    this.stepIndex = 0;
  }

  #restore(stored) {
    this.source = stored.source ?? SOURCE_ONBOARDING;
    this.returnUrl = stored.returnUrl;
    this.progressSaved = stored.progressSaved ?? false;
    this.#snapshot = stored.snapshot;
    // the intro is only ever shown once, before the first selection
    this.showIntro = false;
    this.themeId = stored.themeId;
    this.selectedPairKeys = new Map(stored.selectedPairKeys);
    this.colorMode = stored.colorMode ?? renderedColorMode();
    this.palettesUserSelectable = stored.palettesUserSelectable;
    this.bodyFont = stored.bodyFont;
    this.headingFont = stored.headingFont;
    this.homepage =
      stored.homepage ?? this.#supportedHomepage(this.data.homepage);
    this.categoryPageStyle =
      stored.categoryPageStyle ?? this.siteSettings.desktop_category_page_style;
    this.welcomeBanner =
      stored.welcomeBanner ?? this.siteSettings.enable_welcome_banner;
    this.welcomeBannerLocation =
      stored.welcomeBannerLocation ?? this.siteSettings.welcome_banner_location;
    this.searchExperience =
      stored.searchExperience ?? this.siteSettings.search_experience;
    // selections are restored but the flow always restarts from the first
    // step, so a resumed wizard walks the same path as a fresh one
    this.stepIndex = 0;
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
        welcomeBanner: this.welcomeBanner,
        welcomeBannerLocation: this.welcomeBannerLocation,
        searchExperience: this.searchExperience,
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
    this.siteSettings.enable_welcome_banner = this.welcomeBanner;
    this.siteSettings.welcome_banner_location = this.welcomeBannerLocation;
    this.siteSettings.search_experience = this.searchExperience;
  }

  #refreshCategoriesPage() {
    if (this.router.currentRouteName?.startsWith("discovery.categories")) {
      this.router.refresh();
    }
  }

  #navigateToThemePreview(themeId) {
    DiscourseURL.redirectTo(
      `/?preview_theme_id=${encodeURIComponent(themeId)}`
    );
  }

  #supportedHomepage(homepage) {
    return SUPPORTED_HOMEPAGES.includes(homepage) ? homepage : "latest";
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
