import {
  click,
  currentURL,
  find,
  settled,
  visit,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import {
  captureColorSchemeLinks,
  restoreColorSchemeLinks,
} from "discourse/admin/lib/color-scheme-manager";
import { AUTO_GROUPS } from "discourse/lib/constants";
import DiscourseURL from "discourse/lib/url";
import DesignWizardService from "discourse/services/design-wizard";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const APPEARANCE_LAUNCH_BUTTON =
  ".sidebar-section[data-section-name='admin-appearance'] .sidebar-section-header-button";

const designWizardData = () => ({
  themes: [
    {
      id: -1,
      name: "Foundation",
      default: true,
      default_homepage: "latest",
      color_scheme_id: null,
      dark_color_scheme_id: -2,
      screenshot_light_url: null,
      screenshot_dark_url: null,
      palette_pairs: [
        {
          key: "default",
          name: "Default",
          light: {
            id: -1,
            name: "Light",
            colors: { primary: "222222", secondary: "ffffff" },
          },
          dark: {
            id: -2,
            name: "Dark",
            colors: { primary: "dddddd", secondary: "222222" },
          },
        },
      ],
    },
  ],
  current_theme: null,
  base_font: "inter",
  heading_font: "inter",
  homepage: "latest",
  palettes_user_selectable: false,
});

acceptance("Design wizard - admin launch", function (needs) {
  let savedPayloads = [];
  let wizardData;
  let importRequests;
  let importFails;
  let docked;

  needs.user({
    admin: true,
    visibleGroups: [AUTO_GROUPS.admins],
    can_run_design_wizard: true,
  });

  needs.hooks.beforeEach(function () {
    savedPayloads = [];
    wizardData = designWizardData();
    importRequests = [];
    importFails = false;
    this.originalSchemeLinks = captureColorSchemeLinks();

    // docking follows the viewport, which the test runner doesn't control
    docked = false;
    sinon.stub(DesignWizardService.prototype, "docked").get(function () {
      return this.active && docked;
    });
  });

  // A wizard preview swaps the test page's real color-scheme links, and an
  // exit that relies on a full page load (stubbed here) never puts them back.
  // Left swapped, every later test in the run loses the color variables.
  needs.hooks.afterEach(function () {
    restoreColorSchemeLinks(this.originalSchemeLinks);
  });

  needs.pretender((server, helper) => {
    server.get("/admin/config/design-wizard.json", () =>
      helper.response(200, wizardData)
    );

    server.post("/admin/themes/import", (request) => {
      importRequests.push(helper.parsePostData(request.requestBody));
      return importFails
        ? helper.response(422, { errors: ["Unable to install theme"] })
        : helper.response(201, { theme: { id: 42, name: "Concord" } });
    });

    server.put("/admin/config/design-wizard.json", (request) => {
      savedPayloads.push(helper.parsePostData(request.requestBody));
      return helper.response(200, { success: "OK" });
    });

    server.get("/color-scheme-stylesheet/:id", () =>
      helper.response(200, {
        color_scheme_id: -1,
        new_href: "/stylesheets/color_definitions_preview.css",
      })
    );

    server.get("/color-scheme-stylesheet/:id/:themeId", () =>
      helper.response(200, {
        color_scheme_id: -1,
        new_href: "/stylesheets/color_definitions_preview.css",
      })
    );

    server.get("/admin/config/site_settings.json", () =>
      helper.response(200, { site_settings: [] })
    );
  });

  test("minimizing preserves the preview and selections while browsing", async function (assert) {
    sinon.stub(DiscourseURL, "redirectTo");

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await click(".design-wizard__next");
    await click(
      ".design-wizard__palette-row[data-mode='dark'] [data-pair-key='default']"
    );

    const previewLinks = captureColorSchemeLinks();
    const sections = find(".design-wizard__sections");
    const savedCount = savedPayloads.length;

    await click(".design-wizard__minimize");

    assert
      .dom(".design-wizard")
      .hasAttribute("inert", "", "hides controls from keyboard navigation");
    assert
      .dom(".design-wizard")
      .hasAria("hidden", "true", "hides controls from assistive technology");
    assert
      .dom(".design-wizard__restore")
      .isFocused("moves focus to the restore button");
    assert
      .dom(".design-wizard__restore")
      .hasAria("expanded", "false", "exposes the collapsed state");
    assert
      .dom(".design-wizard__restore")
      .includesText("Step 2/3", "shows the current step");
    assert
      .dom(".dialog-footer")
      .doesNotExist("minimizing does not ask about saved changes");
    assert.strictEqual(
      savedPayloads.length,
      savedCount,
      "minimizing does not save changes"
    );
    assert.deepEqual(
      captureColorSchemeLinks(),
      previewLinks,
      "keeps the palette preview applied"
    );

    await visit("/categories");

    assert
      .dom(".design-wizard__restore")
      .exists("keeps the restore button available on another page");
    await click(".design-wizard__restore");

    assert
      .dom(".design-wizard__restore")
      .doesNotExist("removes the restore bar when expanded");
    assert
      .dom(".design-wizard")
      .doesNotHaveAttribute("inert", "restores keyboard access");
    assert
      .dom(".design-wizard")
      .doesNotHaveAttribute(
        "aria-hidden",
        "restores access for assistive technology"
      );
    assert
      .dom(".design-wizard__minimize")
      .isFocused("returns focus to the panel");
    assert
      .dom(
        ".design-wizard__palette-row[data-mode='dark'] [data-pair-key='default']"
      )
      .hasAria("pressed", "true", "preserves the palette selection");
    assert.strictEqual(
      find(".design-wizard__sections"),
      sections,
      "keeps the controls mounted to retain their scroll position"
    );
    assert.strictEqual(
      savedPayloads.length,
      savedCount,
      "restoring does not save changes"
    );
    assert.deepEqual(
      captureColorSchemeLinks(),
      previewLinks,
      "restoring keeps the palette preview applied"
    );

    await click(".design-wizard__close");
    await click(".dialog-footer .btn-primary");
  });

  test("the wizard can be minimized and a new run opens expanded", async function (assert) {
    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await click(".design-wizard__minimize");

    assert
      .dom(".design-wizard__restore")
      .includesText("Customize your site", "labels the way back to the wizard");
    assert
      .dom(".design-wizard__restore-progress")
      .hasText("Step 1/3", "shows the step progress");

    await click(".design-wizard__restore");
    assert.dom(".design-wizard__theme-card").exists("restores the first step");
    await click(".design-wizard__close");
    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);

    assert
      .dom(".design-wizard")
      .doesNotHaveAttribute("inert", "a fresh run is expanded");
    assert
      .dom(".design-wizard__restore")
      .doesNotExist("a fresh run has no minimized bar");
    await click(".design-wizard__close");
  });

  test("docks beside the page and collapses to a rail on wide screens", async function (assert) {
    docked = true;

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);

    assert
      .dom(document.documentElement)
      .hasClass("design-wizard-docked", "reserves space beside the page");
    assert.dom(".design-wizard").hasClass("--docked");
    assert
      .dom(".design-wizard__step-progress")
      .hasText("Step 1/3", "opens on the first step");

    await click(".design-wizard__next");

    assert
      .dom(".design-wizard__step-progress")
      .hasText("Step 2/3", "shows the current step as text");

    const sections = find(".design-wizard__sections");
    await click(".design-wizard__minimize");

    assert
      .dom(document.documentElement)
      .hasClass("design-wizard-collapsed", "narrows the reserved space");
    assert
      .dom(".design-wizard")
      .doesNotHaveAttribute("inert", "keeps the rail reachable by keyboard");
    assert
      .dom(".design-wizard")
      .doesNotHaveAttribute("aria-hidden", "keeps the rail announced");
    assert
      .dom(".design-wizard__restore")
      .doesNotExist("uses the rail instead of the restore bar");
    assert
      .dom(".design-wizard__expand")
      .isFocused("moves focus to the expand button");
    assert
      .dom(".design-wizard__expand")
      .includesText("Step 2/3", "names the current step");
    assert
      .dom(".design-wizard__expand")
      .hasAria("expanded", "false", "exposes the collapsed state");

    await visit("/categories");

    assert
      .dom(".design-wizard__expand")
      .exists("stays collapsed while browsing");

    await click(".design-wizard__expand");

    assert
      .dom(document.documentElement)
      .doesNotHaveClass("design-wizard-collapsed", "widens the reserved space");
    assert
      .dom(".design-wizard__minimize")
      .isFocused("returns focus to the panel");
    assert.strictEqual(
      find(".design-wizard__sections"),
      sections,
      "keeps the controls mounted to retain their scroll position"
    );

    await click(".design-wizard__close");
    await click(".dialog-footer .btn-primary");

    assert
      .dom(document.documentElement)
      .doesNotHaveClass("design-wizard-docked", "gives the space back");
  });

  test("saves one palette for both system color modes", async function (assert) {
    wizardData.themes[0].palette_pairs.push({
      key: "dracula",
      name: "Dracula",
      light: null,
      dark: {
        id: -11,
        name: "Dracula",
        colors: { primary: "f8f8f2", secondary: "282a36" },
      },
    });
    sinon.stub(DiscourseURL, "redirectTo");

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await click(".design-wizard__next");
    await click(".design-wizard__palette-modes input[value='dark']");
    await click('[data-pair-key="dracula"]');
    await click(".design-wizard__next");

    assert.strictEqual(
      savedPayloads.at(-1).light_palette_id,
      "-11",
      "progress saves Dracula as the default palette for light systems"
    );
    assert.strictEqual(
      savedPayloads.at(-1).dark_palette_id,
      "-11",
      "progress saves Dracula for dark systems"
    );
    assert.strictEqual(
      savedPayloads.at(-1).finishing,
      undefined,
      "a step save can still be reverted, so it is not final"
    );

    await click(".design-wizard__save");
    assert.strictEqual(
      savedPayloads.at(-1).finishing,
      "true",
      "the final save is marked as finishing"
    );

    assert.strictEqual(
      savedPayloads.at(-1).light_palette_id,
      "-11",
      "the final save keeps Dracula as the default palette"
    );
    assert.strictEqual(
      savedPayloads.at(-1).dark_palette_id,
      "-11",
      "the final save keeps Dracula for dark systems"
    );
  });

  test("each step has its own title and description", async function (assert) {
    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);

    assert
      .dom(".design-wizard")
      .hasAria("label", "Customize your site", "the panel keeps one name");
    assert.dom(".design-wizard__title").hasText("Choose a theme");
    assert
      .dom(".design-wizard__description")
      .hasText(
        "Pick the overall look for your site. You can fine-tune it in the next steps."
      );
    assert
      .dom(".design-wizard__section-title")
      .doesNotExist("the step title already names the theme choice");

    await click(".design-wizard__next");

    assert.dom(".design-wizard__title").hasText("Make it yours");
    assert
      .dom(".design-wizard__description")
      .hasText("Add your logo and choose your site's colors.");

    await click(".design-wizard__next");

    assert.dom(".design-wizard__title").hasText("Look & feel");
    assert
      .dom(".design-wizard__description")
      .hasText("Choose your fonts and what members see first.");
  });

  test("a single color mode uses its palette for both", async function (assert) {
    wizardData.themes[0].palette_pairs.push(
      {
        key: "wcag",
        name: "WCAG",
        light: {
          id: -3,
          name: "WCAG",
          colors: { primary: "000000", secondary: "ffffff" },
        },
        dark: {
          id: -10,
          name: "WCAG Dark",
          colors: { primary: "ffffff", secondary: "000000" },
        },
      },
      {
        key: "dracula",
        name: "Dracula",
        light: null,
        dark: {
          id: -11,
          name: "Dracula",
          colors: { primary: "f8f8f2", secondary: "282a36" },
        },
      }
    );
    const LIGHT_ROW = ".design-wizard__palette-row[data-mode='light']";
    const DARK_ROW = ".design-wizard__palette-row[data-mode='dark']";
    const MODE = (value) =>
      `.design-wizard__palette-modes input[value='${value}']`;

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await click(".design-wizard__next");

    assert.dom(MODE("both")).isChecked("starts with both modes");
    assert
      .dom(`${LIGHT_ROW} [data-pair-key='dracula']`)
      .doesNotExist("a dark-only palette is not offered for light mode");
    assert
      .dom(LIGHT_ROW)
      .hasAttribute("role", "group")
      .hasAria("label", "Light palette", "labels the light row");
    assert
      .dom(DARK_ROW)
      .hasAria("label", "Dark palette", "labels the dark row");

    await click(`${LIGHT_ROW} [data-pair-key='wcag']`);
    await click(`${DARK_ROW} [data-pair-key='dracula']`);
    await click(MODE("dark"));

    assert.dom(LIGHT_ROW).doesNotExist("hides the light row");
    assert
      .dom(`${DARK_ROW} [data-pair-key='dracula']`)
      .hasAria("pressed", "true");

    await click(".design-wizard__next");

    assert.strictEqual(
      savedPayloads.at(-1).light_palette_id,
      "-11",
      "saves the dark palette for light systems too"
    );
    assert.strictEqual(savedPayloads.at(-1).dark_palette_id, "-11");

    await click(".design-wizard__back");
    await click(MODE("light"));

    assert.dom(DARK_ROW).doesNotExist("hides the dark row");
    assert
      .dom(`${LIGHT_ROW} [data-pair-key='wcag']`)
      .hasAria("pressed", "true", "keeps the light palette picked earlier");

    await click(".design-wizard__next");

    assert.strictEqual(
      savedPayloads.at(-1).light_palette_id,
      "-3",
      "saves the light palette"
    );
    assert.strictEqual(
      savedPayloads.at(-1).dark_palette_id,
      undefined,
      "saves no dark palette, so the site is light only"
    );

    await click(".design-wizard__back");
    await click(MODE("both"));

    assert
      .dom(`${DARK_ROW} [data-pair-key='dracula']`)
      .hasAria("pressed", "true", "restores the dark palette picked earlier");
  });

  test("a site using one palette for both modes is dark only", async function (assert) {
    wizardData.themes[0].color_scheme_id = 11;
    wizardData.themes[0].dark_color_scheme_id = 11;
    wizardData.themes[0].palette_pairs.push({
      key: "dracula",
      name: "Dracula",
      light: null,
      dark: {
        id: 11,
        name: "Dracula",
        colors: { primary: "f8f8f2", secondary: "282a36" },
      },
    });

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await click(".design-wizard__next");

    assert
      .dom(
        ".design-wizard__palette-row[data-mode='dark'] [data-pair-key='dracula']"
      )
      .hasAria("pressed", "true", "reflects the saved dark palette");
    assert
      .dom(".design-wizard__palette-modes input[value='dark']")
      .isChecked("the same palette in both modes is dark only");
    assert.dom(".design-wizard__palette-row[data-mode='light']").doesNotExist();
  });

  test("a theme without a dark palette is light only", async function (assert) {
    wizardData.themes[0].dark_color_scheme_id = null;

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await click(".design-wizard__next");

    assert
      .dom(".design-wizard__palette-modes input[value='light']")
      .isChecked();
    assert.dom(".design-wizard__palette-row[data-mode='dark']").doesNotExist();
    assert
      .dom(
        ".design-wizard__palette-row[data-mode='light'] [data-pair-key='default']"
      )
      .hasAria("pressed", "true");
  });

  test("installs a remote theme before navigating to its preview", async function (assert) {
    const remoteUrl = "https://github.com/discourse/discourse-concord-theme";
    wizardData.themes.push({
      id: "concord",
      name: "Concord",
      remote_url: remoteUrl,
      palette_pairs: [],
    });
    const redirect = sinon.stub(DiscourseURL, "redirectTo");

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await click('[data-theme-id="concord"] input');

    assert.deepEqual(
      importRequests,
      [{ remote: remoteUrl }],
      "imports the offered repository once"
    );
    assert.true(
      redirect.calledWith("/?preview_theme_id=42"),
      "previews the installed theme ID"
    );
    const stored = JSON.parse(
      this.owner
        .lookup("service:key-value-store")
        .get("design_wizard_panel_state")
    );
    assert.strictEqual(
      stored.themeId,
      42,
      "the installed ID survives the preview reload"
    );
    await click(".design-wizard__close");
  });

  test("switches to Concord's default chat homepage", async function (assert) {
    const remoteUrl = "https://github.com/discourse/discourse-concord-theme";
    wizardData.themes.push({
      id: "concord",
      name: "Concord",
      remote_url: remoteUrl,
      default_homepage: "chat",
      palette_pairs: [],
    });
    wizardData.homepage_settings = { chat_homepage_channel: null };
    wizardData.additional_homepages = [
      {
        id: "chat",
        name: "Chat",
        path: "/chat",
        settings: { chat_homepage_channel: "12" },
      },
    ];
    const redirect = sinon.stub(DiscourseURL, "redirectTo");

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await click('[data-theme-id="concord"] input');

    assert.true(
      redirect.calledWith("/chat?preview_theme_id=42"),
      "previews the installed theme on the chat homepage"
    );
    const stored = JSON.parse(
      this.owner
        .lookup("service:key-value-store")
        .get("design_wizard_panel_state")
    );
    assert.strictEqual(stored.homepage, "chat", "selects the chat homepage");
    assert.strictEqual(
      stored.homepageSettings.chat_homepage_channel,
      "12",
      "uses the General channel"
    );

    // the preview reload now reports the installed theme
    wizardData.themes[1] = {
      id: 42,
      name: "Concord",
      default_homepage: "chat",
      palette_pairs: [],
    };
    const wizard = this.owner.lookup("service:design-wizard");
    wizard.applyingTheme = false;
    await wizard.start({ resuming: true });

    assert.strictEqual(
      wizard.homepage,
      "chat",
      "restores the homepage preview"
    );
    assert.strictEqual(
      savedPayloads.length,
      0,
      "resuming does not save changes"
    );

    await click(".design-wizard__next");

    assert.strictEqual(
      savedPayloads.at(-1).homepage,
      "chat",
      "saves chat as the underlying homepage"
    );
    assert.strictEqual(
      savedPayloads.at(-1).homepage_settings.chat_homepage_channel,
      "12",
      "saves the General channel"
    );
    assert.strictEqual(
      savedPayloads.at(-1).theme_id,
      "42",
      "saves the installed theme"
    );
    await click(".design-wizard__close");
    await click(".dialog-footer .btn-primary");
  });

  test("switches to the selected theme's default homepage", async function (assert) {
    wizardData.themes[0].default = false;
    wizardData.themes.push({
      id: 42,
      name: "Concord",
      default: true,
      default_homepage: "chat",
      palette_pairs: [],
    });
    wizardData.homepage = "categories";
    const redirect = sinon.stub(DiscourseURL, "redirectTo");

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await click('[data-theme-id="-1"] input');

    assert.true(
      redirect.calledWith("/latest?preview_theme_id=-1"),
      "previews the default theme's homepage"
    );
    const stored = JSON.parse(
      this.owner
        .lookup("service:key-value-store")
        .get("design_wizard_panel_state")
    );
    assert.strictEqual(stored.homepage, "latest", "selects the theme default");

    const wizard = this.owner.lookup("service:design-wizard");
    wizard.applyingTheme = false;
    await wizard.start({ resuming: true });

    assert.strictEqual(
      wizard.homepage,
      "latest",
      "restores the homepage preview"
    );
    assert.strictEqual(
      savedPayloads.length,
      0,
      "resuming does not save changes"
    );

    await click(".design-wizard__next");

    assert.strictEqual(
      savedPayloads.at(-1).homepage,
      "latest",
      "saves the theme default as the underlying homepage"
    );
    assert.strictEqual(
      savedPayloads.at(-1).theme_id,
      "-1",
      "saves the selected theme"
    );
    await click(".design-wizard__close");
    await click(".dialog-footer .btn-primary");
  });

  test("keeps the current homepage when the theme's default is unavailable", async function (assert) {
    wizardData.themes.push({
      id: 42,
      name: "Concord",
      default_homepage: "chat",
      palette_pairs: [],
    });
    wizardData.homepage = "categories";
    sinon.stub(DiscourseURL, "redirectTo");

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await click('[data-theme-id="42"] input');

    const wizard = this.owner.lookup("service:design-wizard");
    assert.strictEqual(
      wizard.homepage,
      "categories",
      "keeps the current choice"
    );
    wizard.applyingTheme = false;
    await wizard.start({ resuming: true });

    assert.strictEqual(
      wizard.homepage,
      "categories",
      "restores the current choice"
    );
    assert.strictEqual(
      savedPayloads.length,
      0,
      "resuming does not save changes"
    );

    await click(".design-wizard__next");

    assert.strictEqual(
      savedPayloads.at(-1).homepage,
      undefined,
      "advancing leaves the current homepage alone"
    );
    await click(".design-wizard__close");
    await click(".dialog-footer .btn-primary");
  });

  test("a failed theme install restores the selection and allows retrying", async function (assert) {
    wizardData.themes.push({
      id: "concord",
      name: "Concord",
      remote_url: "https://github.com/discourse/discourse-concord-theme",
      palette_pairs: [],
    });
    importFails = true;
    const redirect = sinon.stub(DiscourseURL, "redirectTo");

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await click('[data-theme-id="concord"] input');

    assert
      .dom(".dialog-body")
      .includesText("Unable to install theme", "shows the installation error");
    assert
      .dom('[data-theme-id="-1"] input')
      .isChecked("restores the previous selection");
    assert
      .dom('[data-theme-id="concord"] input')
      .isNotDisabled("allows another attempt");
    assert.false(redirect.called, "does not navigate to a missing theme");

    await click(".dialog-footer .btn-primary");
    importFails = false;
    await click('[data-theme-id="concord"] input');
    assert.true(
      redirect.calledWith("/?preview_theme_id=42"),
      "a successful retry opens the preview"
    );
    await click(".design-wizard__close");
  });

  test("previews and saves an additional homepage without a destination picker", async function (assert) {
    wizardData.additional_homepages = [
      {
        id: "chat",
        name: "Chat",
        description:
          "Open the General channel when members visit your homepage.",
        icon: "comments",
        illustration: "conversation",
        settings: { chat_homepage_channel: "12" },
        path: "/categories",
      },
    ];
    const redirect = sinon.stub(DiscourseURL, "redirectTo");

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await click(".design-wizard__next");
    await click(".design-wizard__next");
    assert
      .dom('[data-homepage="chat"] .design-wizard__mock-message')
      .exists({ count: 3 });
    assert.dom('[data-homepage="chat"] .design-wizard__mock-composer').exists();
    await click('[data-homepage="chat"]');

    assert.strictEqual(
      currentURL(),
      "/categories",
      "previews the path provided by the server"
    );
    assert
      .dom('[data-homepage="chat"]')
      .hasAttribute("aria-pressed", "true", "selects Chat");
    assert
      .dom('[data-homepage="topics"]')
      .hasAttribute("aria-pressed", "false", "clears the topic selection");
    assert
      .dom(".design-wizard__detail-group")
      .includesText("General", "explains the fixed destination");
    assert
      .dom(".design-wizard__detail-group select")
      .doesNotExist("does not offer a channel picker");
    await click(".design-wizard__save");
    assert.strictEqual(
      savedPayloads.at(-1).homepage,
      "chat",
      "saves the registered homepage"
    );
    assert.strictEqual(
      savedPayloads.at(-1).homepage_settings.chat_homepage_channel,
      "12",
      "uses the General channel provided by the server"
    );
    assert.true(redirect.called, "finishes the wizard");
  });

  test("previews and saves a new logo", async function (assert) {
    this.siteSettings.logo = "";
    sinon.stub(DiscourseURL, "redirectTo");

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await click(".design-wizard__next");

    assert
      .dom(".design-wizard__section")
      .hasClass("--section-logo", "the colors step starts with the logo");
    assert.false(
      "logo" in savedPayloads.at(-1),
      "an untouched logo is not saved"
    );

    const wizard = this.owner.lookup("service:design-wizard");
    wizard.selectLogo({ url: "/uploads/wizard-logo.png" });
    await settled();

    assert
      .dom("#site-logo")
      .hasAttribute("src", "/uploads/wizard-logo.png", "previews the logo");

    await click(".design-wizard__next");
    assert.strictEqual(
      savedPayloads.at(-1).logo,
      "/uploads/wizard-logo.png",
      "saves the new logo with the step"
    );

    wizard.selectLogo(null);
    await wizard.saveProgress();
    assert.strictEqual(
      savedPayloads.at(-1).logo,
      "",
      "removing a logo saved earlier in the run is saved"
    );
  });

  test("closing without saving restores the logo", async function (assert) {
    this.siteSettings.site_logo_url = "/uploads/original-logo.png";
    sinon.stub(DiscourseURL, "redirectTo");

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await click(".design-wizard__next");
    await click(".design-wizard__next");

    const wizard = this.owner.lookup("service:design-wizard");
    wizard.selectLogo(null);
    await settled();
    assert.dom("#site-logo").doesNotExist("previews the removed logo");

    await click(".design-wizard__close");
    await click(".dialog-footer .btn-primary");
    assert
      .dom("#site-logo")
      .hasAttribute(
        "src",
        "/uploads/original-logo.png",
        "restores the original logo"
      );
  });

  test("leaves a homepage the wizard does not offer alone until one is chosen", async function (assert) {
    wizardData.homepage = "new";
    sinon.stub(DiscourseURL, "redirectTo");

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await click(".design-wizard__next");
    await click(".design-wizard__next");
    assert.false(
      "homepage" in savedPayloads.at(-1),
      "saving a step does not replace it with the fallback"
    );

    assert
      .dom('[data-homepage="topics"]')
      .hasAttribute("aria-pressed", "true", "shows the fallback as selected");
    await click('[data-homepage="topics"]');
    const wizard = this.owner.lookup("service:design-wizard");
    await wizard.saveProgress();
    assert.strictEqual(
      savedPayloads.at(-1).homepage,
      "latest",
      "explicitly choosing the fallback saves it"
    );
  });

  test("reverting restores a homepage the wizard does not offer", async function (assert) {
    wizardData.homepage = "new";
    wizardData.restorable_homepages = ["latest", "categories", "new", "hot"];
    sinon.stub(DiscourseURL, "redirectTo");

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await click(".design-wizard__next");
    await click(".design-wizard__next");
    await click('[data-homepage="categories"]');
    const wizard = this.owner.lookup("service:design-wizard");
    await wizard.saveProgress();
    assert.strictEqual(savedPayloads.at(-1).homepage, "categories");

    // a theme preview reloads the page, so the snapshot comes back from the store
    await wizard.start({ resuming: true });
    await click(".design-wizard__close");
    await click(".dialog-footer .btn-danger");
    assert.strictEqual(
      savedPayloads.at(-1).homepage,
      "new",
      "puts the original homepage back"
    );
  });

  test("saves a change back from a homepage saved earlier in the run", async function (assert) {
    sinon.stub(DiscourseURL, "redirectTo");

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await click(".design-wizard__next");
    await click(".design-wizard__next");
    await click('[data-homepage="categories"]');
    const wizard = this.owner.lookup("service:design-wizard");
    await wizard.saveProgress();
    assert.strictEqual(savedPayloads.at(-1).homepage, "categories");

    await click('[data-homepage="topics"]');
    await wizard.saveProgress();
    assert.strictEqual(
      savedPayloads.at(-1).homepage,
      "latest",
      "compares against what was saved, not what the page loaded with"
    );
  });

  ["chat", "latest"].forEach((homepage) => {
    test(`preserves and restores the chat destination from ${homepage}`, async function (assert) {
      wizardData.homepage = homepage;
      wizardData.homepage_settings = { chat_homepage_channel: "23" };
      wizardData.additional_homepages = [
        {
          id: "chat",
          name: "Chat",
          path: "/categories",
          settings: { chat_homepage_channel: "12" },
        },
      ];
      sinon.stub(DiscourseURL, "redirectTo");

      await visit("/admin");
      await click(APPEARANCE_LAUNCH_BUTTON);
      await click(".design-wizard__next");
      assert.strictEqual(
        savedPayloads.at(-1).homepage_settings,
        undefined,
        "Next leaves the existing channel alone"
      );
      await click(".design-wizard__next");
      await click('[data-homepage="chat"]');
      const wizard = this.owner.lookup("service:design-wizard");
      await wizard.saveProgress();
      assert.strictEqual(
        savedPayloads.at(-1).homepage_settings.chat_homepage_channel,
        "12",
        "explicitly selecting Chat chooses General"
      );

      await wizard.start({ resuming: true });
      await wizard.saveProgress();
      assert.strictEqual(
        savedPayloads.at(-1).homepage_settings.chat_homepage_channel,
        "12",
        "the selection survives a preview reload"
      );
      await click(".design-wizard__close");
      await click(".dialog-footer .btn-danger");
      assert.strictEqual(
        savedPayloads.at(-1).homepage,
        homepage,
        "reverts the original homepage"
      );
      assert.strictEqual(
        savedPayloads.at(-1).homepage_settings.chat_homepage_channel,
        "23",
        "reverts the original channel after resuming"
      );
    });
  });

  test("resuming drops homepage options that are no longer available", async function (assert) {
    wizardData.homepage = "chat";
    wizardData.homepage_settings = { chat_homepage_channel: "23" };
    wizardData.additional_homepages = [
      {
        id: "chat",
        name: "Chat",
        path: "/categories",
        settings: { chat_homepage_channel: "12" },
      },
    ];
    sinon.stub(DiscourseURL, "redirectTo");

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);

    wizardData.additional_homepages = [];
    wizardData.homepage_settings = {};
    const wizard = this.owner.lookup("service:design-wizard");
    await wizard.start({ resuming: true });
    await wizard.saveProgress();

    assert.strictEqual(
      savedPayloads.at(-1).homepage,
      undefined,
      "the fallback shown for an unavailable homepage is not saved"
    );
    assert.strictEqual(savedPayloads.at(-1).homepage_settings, undefined);

    await click(".design-wizard__next");
    await click(".design-wizard__next");
    await click('[data-homepage="categories"]');
    await wizard.saveProgress();
    assert.strictEqual(
      savedPayloads.at(-1).homepage_settings,
      undefined,
      "selecting a homepage does not reintroduce unavailable original settings"
    );

    await click(".design-wizard__close");
    await click(".dialog-footer .btn-danger");
    assert.strictEqual(savedPayloads.at(-1).homepage, "");
    assert.strictEqual(
      savedPayloads.at(-1).homepage_settings,
      undefined,
      "reverting does not send unavailable snapshot settings"
    );
  });

  ["topics", "categories"].forEach((choice) => {
    [false, true].forEach((resume) => {
      test(`switching from Chat to ${choice} preserves the original channel${resume ? " after a preview reload" : ""}`, async function (assert) {
        wizardData.homepage_settings = { chat_homepage_channel: "23" };
        wizardData.additional_homepages = [
          {
            id: "chat",
            name: "Chat",
            path: "/categories",
            settings: { chat_homepage_channel: "12" },
          },
        ];
        sinon.stub(DiscourseURL, "redirectTo");

        await visit("/admin");
        await click(APPEARANCE_LAUNCH_BUTTON);
        await click(".design-wizard__next");
        await click(".design-wizard__next");
        await click('[data-homepage="chat"]');

        if (resume) {
          const wizard = this.owner.lookup("service:design-wizard");
          await wizard.saveProgress();
          wizardData.homepage = "chat";
          wizardData.homepage_settings = { chat_homepage_channel: "12" };
          await wizard.start({ resuming: true });
          await click(".design-wizard__next");
          await click(".design-wizard__next");
        }

        await click(`[data-homepage="${choice}"]`);
        await click(".design-wizard__save");

        // without a saved detour, going back to topics is the homepage the
        // site already has, so there is nothing to save
        const unchanged = !resume && choice === "topics";
        const homepage = choice === "topics" ? "latest" : "categories";
        assert.strictEqual(
          savedPayloads.at(-1).homepage,
          unchanged ? undefined : homepage,
          "saves the selected forum homepage only when it changed"
        );
        assert.strictEqual(
          savedPayloads.at(-1).homepage_settings?.chat_homepage_channel,
          unchanged ? undefined : "23",
          "restores the channel configured before the wizard started"
        );
      });
    });
  });

  test("the appearance section launches the wizard on the forum", async function (assert) {
    await visit("/admin");

    assert
      .dom(APPEARANCE_LAUNCH_BUTTON)
      .exists("the appearance section offers a launcher");

    await click(APPEARANCE_LAUNCH_BUTTON);
    await waitFor(".design-wizard");

    assert.dom(".design-wizard").exists("the sheet slides in");
    assert.strictEqual(
      currentURL(),
      "/latest",
      "leaves the admin interface, so the page behind the sheet is the preview"
    );
    assert
      .dom(".design-wizard__theme-card")
      .exists("opens straight on the first step");
    assert.strictEqual(savedPayloads.length, 0, "nothing is saved yet");

    // close the sheet so the palette preview does not leak into other tests
    await click(".design-wizard__close");
  });

  test("closing a run that already saved a step offers to revert", async function (assert) {
    // leaving is a full page load, which is a no-op under test
    const redirect = sinon.stub(DiscourseURL, "redirectTo");

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await waitFor(".design-wizard__theme-card");
    assert.dom(".design-wizard__theme-card").exists("the first step is shown");

    await click(".design-wizard__next");
    await waitUntil(() => savedPayloads.length === 1);
    assert.strictEqual(
      savedPayloads.length,
      1,
      "completing a step saves it to the live site"
    );

    await click(".design-wizard__close");
    assert
      .dom(".dialog-footer .btn-danger")
      .exists("closing offers to put the site back");

    await click(".dialog-footer .btn-danger");
    await waitUntil(() => savedPayloads.length === 2);

    assert.strictEqual(
      savedPayloads[1].theme_id,
      "-1",
      "reverts to the theme the site started on"
    );
    assert.strictEqual(
      savedPayloads[1].base_font,
      "inter",
      "reverts the fonts the site started with"
    );
    assert.true(
      redirect.calledWith("/admin"),
      "returns to the admin page the wizard was launched from"
    );
  });

  test("a fresh launch ignores an abandoned run", async function (assert) {
    // a run whose tab was closed rather than dismissed, so its state was left
    // behind in the key value store
    window.localStorage.setItem(
      "discourse_design_wizard_panel_state",
      JSON.stringify({
        themeId: -1,
        paletteSelections: [],
        source: "onboarding",
        returnUrl: "/somewhere-else",
        progressSaved: true,
      })
    );

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await waitFor(".design-wizard");

    assert
      .dom(".design-wizard__theme-card")
      .exists("the abandoned run's steps are not resumed");

    await click(".design-wizard__close");
    assert
      .dom(".dialog-footer")
      .doesNotExist("the abandoned run's saved steps are not this run's");
    assert.dom(".design-wizard").doesNotExist("the sheet closes");
  });

  test("a run that saved nothing closes without asking", async function (assert) {
    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await waitFor(".design-wizard__close");

    await click(".design-wizard__close");

    assert.dom(".dialog-footer").doesNotExist("nothing to decide about");
    assert.dom(".design-wizard").doesNotExist("the sheet closes");
  });
});

acceptance("Design wizard - moderators", function (needs) {
  needs.user({ moderator: true, admin: false });

  test("moderators are not offered the wizard", async function (assert) {
    await visit("/admin");

    assert
      .dom(".sidebar-section[data-section-name='admin-appearance']")
      .doesNotExist("the appearance section is admin-only to begin with");
    assert
      .dom(APPEARANCE_LAUNCH_BUTTON)
      .doesNotExist("so the launcher cannot be reached");
  });
});

acceptance("Design wizard - customized site", function (needs) {
  // a site that has installed a theme or moved off the core themes has grown
  // past what the wizard can express
  needs.user({
    admin: true,
    visibleGroups: [AUTO_GROUPS.admins],
    can_run_design_wizard: false,
  });

  needs.pretender((server, helper) => {
    server.get("/admin/config/site_settings.json", () =>
      helper.response(200, { site_settings: [] })
    );
  });

  test("the launcher is not offered", async function (assert) {
    await visit("/admin");

    assert
      .dom(".sidebar-section[data-section-name='admin-appearance']")
      .exists("the appearance section is still there");
    assert
      .dom(APPEARANCE_LAUNCH_BUTTON)
      .doesNotExist("but the wizard is not offered any more");
  });
});
