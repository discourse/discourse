import {
  click,
  currentURL,
  visit,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
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

  needs.user({
    admin: true,
    groups: [AUTO_GROUPS.admins],
    can_run_design_wizard: true,
  });

  needs.hooks.beforeEach(function () {
    savedPayloads = [];
  });

  needs.pretender((server, helper) => {
    server.get("/admin/config/design-wizard.json", () =>
      helper.response(200, designWizardData())
    );

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
    groups: [AUTO_GROUPS.admins],
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
