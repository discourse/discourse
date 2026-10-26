import {
  click,
  currentURL,
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
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const APPEARANCE_LAUNCH_BUTTON =
  ".sidebar-section[data-section-name='admin-appearance'] .sidebar-section-header-button";

const designWizardData = () => ({
  themes: [
    {
      id: -1,
      name: "Foundation",
      default: true,
      color_scheme_id: null,
      dark_color_scheme_id: null,
      screenshot_light_url: null,
      screenshot_dark_url: null,
      palette_pairs: [
        {
          key: "default",
          name: "Default",
          dark_only: false,
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
    await click(".design-wizard__intro-start");
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
    await click(".design-wizard__intro-start");
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
    await click(".design-wizard__intro-start");
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
    assert.dom("[data-topic-page]").doesNotExist("hides topic list choices");
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

  test("omits unsupported welcome and search choices", async function (assert) {
    wizardData.themes[0].supports_welcome_banner = false;
    wizardData.themes[0].supports_search = false;
    sinon.stub(DiscourseURL, "redirectTo");

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await click(".design-wizard__intro-start");
    await click(".design-wizard__next");
    await click(".design-wizard__next");

    assert.dom(".design-wizard__sections").doesNotIncludeText("Welcome banner");
    assert.dom(".design-wizard__sections").doesNotIncludeText("Search");
    await click(".design-wizard__save");
    for (const key of [
      "enable_welcome_banner",
      "welcome_banner_location",
      "search_experience",
    ]) {
      assert.false(key in savedPayloads.at(-1), `${key} is not saved`);
    }
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
      await click(".design-wizard__intro-start");
      await click(".design-wizard__next");
      assert.strictEqual(
        savedPayloads.at(-1).homepage_settings.chat_homepage_channel,
        "23",
        "Next preserves the existing channel"
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
        await click(".design-wizard__intro-start");
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
        assert.strictEqual(
          savedPayloads.at(-1).homepage,
          choice === "topics" ? "latest" : "categories",
          "saves the selected forum homepage"
        );
        assert.strictEqual(
          savedPayloads.at(-1).homepage_settings.chat_homepage_channel,
          "23",
          "restores the channel configured before the wizard started"
        );
      });
    });
  });

  test("reverts the welcome banner location after switching from Concord", async function (assert) {
    wizardData.themes[0].default = false;
    wizardData.themes.push({
      id: 42,
      name: "Concord",
      default: true,
      supports_welcome_banner: false,
      supports_search: false,
      palette_pairs: [],
    });
    this.siteSettings.welcome_banner_location = "top_menu";
    sinon.stub(DiscourseURL, "redirectTo");

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await click(".design-wizard__intro-start");
    await click('[data-theme-id="-1"] input');
    const wizard = this.owner.lookup("service:design-wizard");
    await wizard.start({ resuming: true });
    wizard.applyingTheme = false;
    await click(".design-wizard__next");
    await click(".design-wizard__next");
    wizard.selectWelcomeBannerLocation("all");
    await click(".design-wizard__back");
    await click(".design-wizard__next");
    assert.strictEqual(
      savedPayloads.at(-1).welcome_banner_location,
      "all",
      "saves the changed site-wide location"
    );
    await click(".design-wizard__close");
    await click(".dialog-footer .btn-danger");
    assert.strictEqual(
      savedPayloads.at(-1).theme_id,
      "42",
      "reverts to Concord"
    );
    assert.strictEqual(
      savedPayloads.at(-1).welcome_banner_location,
      "top_menu",
      "restores the original site-wide location"
    );
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
      .dom(".design-wizard__intro")
      .exists("a re-run says what it is about to change before changing it");
    assert
      .dom(".design-wizard__theme-card")
      .doesNotExist("the steps wait until the intro is acknowledged");
    assert.strictEqual(savedPayloads.length, 0, "nothing is saved yet");

    // close the sheet so the palette preview does not leak into other tests
    await click(".design-wizard__close");
  });

  test("closing a run that already saved a step offers to revert", async function (assert) {
    // leaving is a full page load, which is a no-op under test
    const redirect = sinon.stub(DiscourseURL, "redirectTo");

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await waitFor(".design-wizard__intro-start");

    await click(".design-wizard__intro-start");
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
        selectedPairKeys: [],
        source: "onboarding",
        returnUrl: "/somewhere-else",
        progressSaved: true,
      })
    );

    await visit("/admin");
    await click(APPEARANCE_LAUNCH_BUTTON);
    await waitFor(".design-wizard");

    assert
      .dom(".design-wizard__intro")
      .exists("the abandoned run does not skip this one's intro");

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
