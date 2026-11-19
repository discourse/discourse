import { action } from "@ember/object";
import { click, currentURL, fillIn, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import AdminOnboardingBanner from "discourse/components/admin-onboarding/banner";
import OnboardingStep from "discourse/components/admin-onboarding/step";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setDefaultHomepage } from "discourse/lib/utilities";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const designWizardData = () => ({
  themes: [
    {
      id: -1,
      name: "Foundation",
      default: true,
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
            colors: {
              primary: "222222",
              secondary: "ffffff",
              tertiary: "0088cc",
            },
          },
          dark: {
            id: -2,
            name: "Dark",
            colors: {
              primary: "dddddd",
              secondary: "222222",
              tertiary: "099dd7",
            },
          },
        },
      ],
    },
    {
      id: -2,
      name: "Horizon",
      default: false,
      color_scheme_id: 23,
      dark_color_scheme_id: 24,
      screenshot_light_url: null,
      screenshot_dark_url: null,
      palette_pairs: [
        {
          key: "horizon",
          name: "Horizon",
          light: {
            id: 23,
            name: "Horizon",
            colors: {
              primary: "222222",
              secondary: "ffffff",
              tertiary: "563fe3",
            },
          },
          dark: {
            id: 24,
            name: "Horizon Dark",
            colors: {
              primary: "e7e5f2",
              secondary: "1b1533",
              tertiary: "7965f0",
            },
          },
        },
        {
          key: "marigold",
          name: "Marigold",
          light: {
            id: 25,
            name: "Marigold",
            colors: {
              primary: "222222",
              secondary: "ffffff",
              tertiary: "b78d12",
            },
          },
          dark: {
            id: 26,
            name: "Marigold Dark",
            colors: {
              primary: "efe7d4",
              secondary: "201808",
              tertiary: "d9a616",
            },
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

const withStep = (id, assert) => {
  return {
    checkbox() {
      return assert.dom(`div#${id} .onboarding-step__checkbox > svg`);
    },
    clickAction() {
      return click(`div#${id} .onboarding-step__action .btn`);
    },
    isChecked() {
      return this.checkbox().hasClass("--completed", `${id} step is completed`);
    },
    isNotChecked() {
      return this.checkbox().doesNotHaveClass(
        "--completed",
        `${id} step is not completed`
      );
    },
  };
};

acceptance("Admin - Onboarding Banner", function (needs) {
  const loggedEvents = [];

  needs.user({
    admin: true,
    can_create_category: true,
    visibleGroups: [AUTO_GROUPS.admins],
    show_site_owner_onboarding: true,
  });

  needs.settings({
    enable_site_owner_onboarding: true,
  });

  needs.hooks.beforeEach(function () {
    loggedEvents.length = 0;
    this.schemeLinks = [];

    // registered so afterEach tears them down even when an assertion throws
    this.addSchemeLink = (className, href, media) => {
      const element = document.createElement("link");
      element.rel = "stylesheet";
      element.className = className;
      element.href = href;
      element.media = media;
      document.head.prepend(element);
      this.schemeLinks.push(element);
      return element;
    };
  });

  needs.hooks.afterEach(function () {
    this.schemeLinks.forEach((link) => link.remove());
  });

  needs.pretender((server, helper) => {
    server.put("/admin/site_settings/enable_site_owner_onboarding", () => {
      return helper.response(200, {
        success: "OK",
      });
    });

    server.post("/admin/onboarding/events", (request) => {
      loggedEvents.push(helper.parsePostData(request.requestBody));
      return helper.response(200, { success: "OK" });
    });

    server.post("/invites", () => {
      return helper.response(200, {
        success: "OK",
      });
    });

    server.put("/admin/config/design-wizard.json", () =>
      helper.response(200, { success: "OK" })
    );

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

    server.get("/admin/config/design-wizard.json", () =>
      helper.response(200, designWizardData())
    );
  });

  test("it shows onboarding banner", async function (assert) {
    await visit("/");
    assert.dom(".admin-onboarding-banner").exists("shows onboarding banner");
  });

  test("the header controls have accessible labels", async function (assert) {
    await visit("/");

    assert
      .dom(".admin-onboarding-banner .btn-minimize")
      .hasAttribute(
        "aria-label",
        "Collapse setup steps",
        "labels the collapse action"
      );
    assert
      .dom(".admin-onboarding-banner .btn-close")
      .hasAttribute("aria-label", "Dismiss setup", "labels the dismiss action");

    await click(".admin-onboarding-banner .btn-minimize");

    assert
      .dom(".admin-onboarding-banner .btn-minimize")
      .hasAttribute(
        "aria-label",
        "Expand setup steps",
        "updates the label for the expand action"
      );
  });

  test("it can end onboarding prematurely", async function (assert) {
    await visit("/");
    assert.dom(".admin-onboarding-banner").exists();

    await click(".admin-onboarding-banner .btn-close");
    assert.dom(".admin-onboarding-banner").doesNotExist();
    assert.deepEqual(
      loggedEvents,
      [{ event: "dismissed" }],
      "logs a dismissed staff action"
    );
  });

  test("creating a category comes before inviting collaborators", async function (assert) {
    await visit("/");
    assert.deepEqual(
      [...document.querySelectorAll(".onboarding-step")].map((step) => step.id),
      ["select_theme", "create_category", "invite_collaborators"]
    );
  });

  test("it completes `create_category` once a new category is saved", async function (assert) {
    const step = withStep("create_category", assert);
    await visit("/");
    step.isNotChecked();

    await step.clickAction();
    assert.strictEqual(
      currentURL(),
      "/new-category/general",
      "goes through the category setup"
    );
    assert.strictEqual(
      loggedEvents.length,
      0,
      "opening the category setup is not completion"
    );

    await fillIn("input.category-name", "testing");
    await click("#save-category");
    assert.strictEqual(currentURL(), "/c/testing/edit/general");
    assert.deepEqual(
      loggedEvents,
      [{ event: "step_completed", step: "create_category" }],
      "logs the completion from the category form"
    );

    await visit("/");
    step.isChecked();
  });

  test("the minimized progress counts a category created away from the banner", async function (assert) {
    this.container
      .lookup("service:key-value-store")
      .set({ key: "onboarding_step_select_theme", value: true });

    await visit("/");
    await click(".admin-onboarding-banner .btn-minimize");
    assert
      .dom(".admin-onboarding-banner__subtitle")
      .hasText("1 of 3 steps completed");

    await visit("/new-category");
    await fillIn("input.category-name", "testing");
    await click("#save-category");
    await visit("/");

    assert
      .dom(".admin-onboarding-banner__subtitle")
      .hasText("2 of 3 steps completed");
  });

  test("it finishes onboarding when `create_category` is the last step done", async function (assert) {
    const keyValueStore = this.container.lookup("service:key-value-store");
    keyValueStore.set({ key: "onboarding_step_select_theme", value: true });
    keyValueStore.set({
      key: "onboarding_step_invite_collaborators",
      value: true,
    });

    await visit("/new-category");
    await fillIn("input.category-name", "testing");
    await click("#save-category");
    await visit("/");

    assert
      .dom(".admin-onboarding-banner")
      .doesNotExist("ends onboarding on returning to the banner");
    assert.deepEqual(loggedEvents, [
      { event: "step_completed", step: "create_category" },
      { event: "completed" },
    ]);
  });

  test("a registered step can stand in for `create_category`", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer("admin-onboarding-steps", ({ value }) =>
        value.map((Step) =>
          Step.name === "create_category"
            ? class CreateChannel extends OnboardingStep {
                static name = "create_category";

                i18nKey = "admin_onboarding_banner.custom.";

                get description() {
                  return "Open a channel for your members.";
                }

                @action
                performAction() {
                  this.markAsCompleted();
                }
              }
            : Step
        )
      );
    });

    const step = withStep("create_category", assert);
    await visit("/");

    assert.deepEqual(
      [...document.querySelectorAll(".onboarding-step")].map((el) => el.id),
      ["select_theme", "create_category", "invite_collaborators"],
      "keeps the stand-in step in the replaced step's place"
    );
    assert
      .dom("#create_category .onboarding-step__title")
      .includesText(
        "custom.create_category.title",
        "reads the title from the step's own locale keys"
      );
    assert
      .dom("#create_category .onboarding-step__description")
      .hasText(
        "Open a channel for your members.",
        "renders the step's own description"
      );
    assert
      .dom("#create_category .onboarding-step__action .btn")
      .includesText(
        "custom.create_category.action",
        "reads the action label from the step's own locale keys"
      );
    step.isNotChecked();

    await step.clickAction();

    step.isChecked();
    assert.deepEqual(
      loggedEvents,
      [{ event: "step_completed", step: "create_category" }],
      "logs the completion under the replaced step"
    );
  });

  test("it can complete `invite_collaborators` step", async function (assert) {
    const step = withStep("invite_collaborators", assert);
    await visit("/");

    step.isNotChecked();

    await step.clickAction();
    await click(".d-modal__footer .btn-primary");
    await click(".modal-close");

    step.isChecked();
    assert.deepEqual(
      loggedEvents,
      [{ event: "step_completed", step: "invite_collaborators" }],
      "logs a step_completed staff action once"
    );
  });

  test("it can walk the design wizard from the `select_theme` step", async function (assert) {
    const step = withStep("select_theme", assert);

    await visit("/");

    step.isNotChecked();
    await step.clickAction();
    await settled();

    assert
      .dom(".design-wizard")
      .exists("the design wizard slides in as a sheet");
    assert
      .dom(".design-wizard__theme-card")
      .exists({ count: 2 }, "the theme step shows Foundation and Horizon");
    assert
      .dom(".design-wizard__theme-card.--selected")
      .hasAttribute("data-theme-id", "-1", "preselects the default theme");
    assert
      .dom(".design-wizard__back")
      .isDisabled("cannot go back from the first step");

    await click(".design-wizard__next");
    assert
      .dom(".design-wizard__theme-card")
      .doesNotExist("theme cards are left behind on the colors step");
    assert
      .dom(
        ".design-wizard__palette-row[data-mode='light'] .design-wizard__palette-card"
      )
      .exists({ count: 1 }, "the colors step shows the theme's light palettes");

    await click(
      ".design-wizard__palette-row[data-mode='light'] [data-pair-key='default']"
    );
    assert
      .dom("link[data-scheme-id]", document.documentElement)
      .exists("the page's color scheme stylesheet is swapped for the preview");

    assert
      .dom(".design-wizard__section")
      .hasClass("--section-logo", "the colors step starts with the logo");

    await click(".design-wizard__next");
    assert
      .dom(".design-wizard__font-select")
      .exists({ count: 2 }, "the last step offers the font dropdowns");
    assert
      .dom(".design-wizard__homepage-card")
      .exists({ count: 2 }, "the homepage step offers topics and categories");
    assert
      .dom(".design-wizard__homepage-card.--selected")
      .hasAttribute("data-homepage", "topics", "defaults to a topics homepage");
    assert
      .dom(".design-wizard__detail-group")
      .doesNotExist("a topics homepage has no further choices");
    assert
      .dom(".design-wizard__section")
      .exists({ count: 2 }, "the last step offers the fonts and homepage");

    await click(".design-wizard__homepage-card[data-homepage='categories']");
    assert
      .dom(".design-wizard__style-block")
      .exists({ count: 3 }, "a categories homepage offers the page styles");
    assert
      .dom(".design-wizard__style-block.--selected")
      .hasAttribute(
        "data-style",
        "categories_boxes",
        "defaults to boxes with subcategories"
      );

    assert
      .dom(".admin-onboarding-banner")
      .exists("keeps onboarding visible on the categories preview");
    assert.dom(".design-wizard__next").doesNotExist("no next on the last step");
    assert.dom(".design-wizard__save").exists("the last step offers save");

    await click(".design-wizard__back");
    assert
      .dom(".design-wizard__palette-row[data-mode='light']")
      .exists("back returns to the colors step");

    await click(".design-wizard__close");
    assert.dom(".design-wizard").doesNotExist("closing removes the sheet");
    assert
      .dom("link[data-scheme-id]", document.documentElement)
      .doesNotExist("the palette preview is reverted");

    // closing without saving leaves the step incomplete
    await visit("/");
    step.isNotChecked();
  });

  test("the design wizard activates the stylesheet for the mode of the picked palette", async function (assert) {
    const darkLink = this.addSchemeLink(
      "dark-scheme",
      "data:text/css,design-wizard-dark",
      "none"
    );
    const lightLink = this.addSchemeLink(
      "light-scheme",
      "data:text/css,design-wizard-light",
      "all"
    );

    await visit("/");
    await withStep("select_theme", assert).clickAction();
    await click(".design-wizard__next");
    await click(
      ".design-wizard__palette-row[data-mode='dark'] [data-pair-key='default']"
    );

    assert
      .dom(lightLink)
      .hasAttribute("media", "none", "deactivates the light stylesheet");
    assert
      .dom(darkLink)
      .hasAttribute("media", "all", "activates the dark stylesheet");

    await click(".design-wizard__close");
    assert
      .dom(lightLink)
      .hasAttribute(
        "href",
        "data:text/css,design-wizard-light",
        "restores the original light stylesheet"
      )
      .hasAttribute("media", "all", "reactivates the light stylesheet");
    assert
      .dom(darkLink)
      .hasAttribute(
        "href",
        "data:text/css,design-wizard-dark",
        "restores the original dark stylesheet"
      )
      .hasAttribute("media", "none", "deactivates the dark stylesheet");
  });

  test("the design wizard keeps a custom default theme until another theme is chosen", async function (assert) {
    const data = designWizardData();
    data.themes.forEach((theme) => (theme.default = false));
    data.current_theme = { id: 42, name: "Air" };
    pretender.get("/admin/config/design-wizard.json", () => response(data));

    await visit("/");
    await withStep("select_theme", assert).clickAction();
    await settled();

    assert
      .dom(".design-wizard")
      .exists("the wizard opens without reloading into a theme preview");
    assert
      .dom(".design-wizard__theme-card.--selected")
      .doesNotExist("no theme is preselected");
    assert
      .dom(".design-wizard__custom-theme-notice")
      .includesText("Air", "the notice names the current custom theme");
    assert
      .dom(".design-wizard__next")
      .isDisabled("cannot continue until a theme is chosen");

    await click(".design-wizard__close");
    assert
      .dom("link[data-scheme-id]", document.documentElement)
      .doesNotExist("closing leaves the current theme's palette untouched");
  });

  test("the design wizard stays on the step when saving progress fails", async function (assert) {
    pretender.put("/admin/config/design-wizard.json", () =>
      response(422, { errors: ["Something went wrong"] })
    );

    await visit("/");
    await withStep("select_theme", assert).clickAction();

    assert
      .dom(".design-wizard__theme-card")
      .exists({ count: 2 }, "starts on the theme step");

    await click(".design-wizard__next");

    assert
      .dom(".design-wizard__theme-card")
      .exists({ count: 2 }, "a failed progress save does not advance the step");
    assert
      .dom(".design-wizard__palette-row")
      .doesNotExist("the colors step is not reached");
    assert
      .dom(".design-wizard__next")
      .isNotDisabled("the next button is usable again after the failure");

    await click(".dialog-footer .btn-primary");
    // close the sheet so the palette preview does not leak into other tests
    await click(".design-wizard__close");
  });
});

acceptance("Admin - Onboarding Banner - admin invites", function (needs) {
  needs.user({
    admin: true,
    visibleGroups: [AUTO_GROUPS.admins],
    show_site_owner_onboarding: true,
    can_create_admin_invite: true,
  });

  needs.settings({
    enable_site_owner_onboarding: true,
    enable_invite_modal_with_roles: true,
  });

  needs.pretender((server, helper) => {
    server.put("/admin/site_settings/enable_site_owner_onboarding", () => {
      return helper.response(200, { success: "OK" });
    });

    server.post("/admin/onboarding/events", () => {
      return helper.response(200, { success: "OK" });
    });

    server.post("/invites", () => {
      return helper.response(200, {
        id: 42,
        invite_key: "abc123",
        link: "http://example.com/invites/abc123",
        email: "new-admin@example.com",
        grants_admin: true,
        expires_at: "2100-01-01 00:00",
      });
    });
  });

  test("the invite step opens the role-based modal defaulted to admins and completes", async function (assert) {
    const step = withStep("invite_collaborators", assert);
    await visit("/");

    step.isNotChecked();

    await step.clickAction();

    assert
      .dom(".create-invite-with-roles-modal")
      .exists("opens the role-based invite modal");
    assert
      .dom(
        ".create-invite-with-roles-modal input[name='invite-role'][value='admin']"
      )
      .isChecked("defaults to the admins tab");

    await click(
      ".create-invite-with-roles-modal .form-kit__inline-radio input[value='email']"
    );
    await fillIn(
      ".create-invite-with-roles-modal input[name='email']",
      "new-admin@example.com"
    );
    await click(".create-invite-with-roles-modal .save-invite");
    await click(".modal-close");

    step.isChecked();
  });
});

acceptance("Admin - Onboarding Banner - non admin user", function (needs) {
  needs.user({ admin: false });
  needs.settings({
    enable_site_owner_onboarding: true,
  });

  test("it does not show onboarding banner for non admin user", async function (assert) {
    await visit("/");
    assert
      .dom(".admin-onboarding-banner")
      .doesNotExist("does not show onboarding banner");
  });
});

acceptance("Admin - Onboarding Banner - setting disabled", function (needs) {
  needs.user({
    admin: true,
    visibleGroups: [AUTO_GROUPS.admins],
  });
  needs.settings({
    enable_site_owner_onboarding: false,
  });

  test("it does not show onboarding banner when setting is disabled", async function (assert) {
    await visit("/");
    assert
      .dom(".admin-onboarding-banner")
      .doesNotExist("does not show onboarding banner");
  });
});

acceptance("Admin - Onboarding Banner - relocated banner", function (needs) {
  needs.user({ admin: true, show_site_owner_onboarding: true });
  needs.settings({ enable_site_owner_onboarding: true });

  test("renders only at the render point matching the transformed location", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer(
        "admin-onboarding-banner-location",
        () => "custom_spot"
      );
      api.renderInOutlet(
        "below-site-header",
        <template>
          <div class="custom-spot">
            <AdminOnboardingBanner @location="custom_spot" />
          </div>
        </template>
      );
    });

    await visit("/");

    assert
      .dom(".admin-onboarding-banner")
      .exists({ count: 1 }, "renders the banner once");
    assert
      .dom(".custom-spot .admin-onboarding-banner")
      .exists("renders at the render point that claimed the location");
    assert
      .dom("#main-outlet .admin-onboarding-banner")
      .doesNotExist("leaves the default render point empty");
  });
});

acceptance("Admin - Onboarding Banner - registered homepage", function (needs) {
  needs.user({ admin: true, show_site_owner_onboarding: true });
  needs.settings({ enable_site_owner_onboarding: true });
  needs.site({
    homepage_options: [{ id: "custom", path: "/tags", server_side: false }],
  });

  test("shows the checklist on homepage choices and hides it elsewhere", async function (assert) {
    await visit("/latest");
    setDefaultHomepage("custom");
    await visit("/tags");

    assert
      .dom(".admin-onboarding-banner")
      .exists("shows onboarding on a registered homepage");
    for (const homepagePath of ["/latest", "/categories"]) {
      await visit(homepagePath);
      assert
        .dom(".admin-onboarding-banner")
        .exists(`shows onboarding on ${homepagePath}`);
    }
    await visit("/about");
    assert
      .dom(".admin-onboarding-banner")
      .doesNotExist("keeps onboarding off other pages");
  });
});
