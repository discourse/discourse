import { action } from "@ember/object";
import { service } from "@ember/service";
import { click, fillIn, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import StartPostingOption from "discourse/components/admin-onboarding/start-posting-option";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const withStep = (id, assert) => {
  return {
    checkbox() {
      return assert.dom(`div#${id} .onboarding-step__checkbox > svg`);
    },
    clickAction() {
      return click(`div#${id} .onboarding-step__action .btn`);
    },
    isChecked() {
      return this.checkbox().hasClass("checked", `${id} step is completed`);
    },
    isNotChecked() {
      return this.checkbox().doesNotHaveClass(
        "checked",
        `${id} step is not completed`
      );
    },
  };
};

acceptance("Admin - Onboarding Banner", function (needs) {
  let loggedEvents = [];

  needs.user({
    admin: true,
    groups: [AUTO_GROUPS.admins],
    show_site_owner_onboarding: true,
  });

  needs.settings({
    enable_site_owner_onboarding: true,
    general_category_id: 1,
    default_composer_category: 1,
  });

  needs.hooks.beforeEach(() => (loggedEvents = []));

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

    server.get("/admin/config/design-wizard.json", () => {
      return helper.response(200, {
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
                user_selectable: false,
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
                dark_only: false,
                user_selectable: false,
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
                dark_only: false,
                user_selectable: false,
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
        category_page_styles: [
          {
            name: "category_page_style.categories_only",
            value: "categories_only",
          },
          {
            name: "category_page_style.categories_boxes",
            value: "categories_boxes",
          },
        ],
        palettes_user_selectable: false,
      });
    });
  });

  test("it shows onboarding banner", async function (assert) {
    await visit("/");
    assert.dom(".admin-onboarding-banner").exists("shows onboarding banner");
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

  test("it can complete `start_posting` step with predefined data", async function (assert) {
    const step = withStep("start_posting", assert);
    await visit("/");

    step.isNotChecked();

    await step.clickAction();

    assert.dom(".predefined-topic-options-modal__card").exists({ count: 4 });
    await click(".predefined-topic-options-modal__card:last-child");

    await click(".create");
    await visit("/");

    step.isChecked();
  });

  test("it can complete `start_posting` step with registered posting-options", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer(
        "admin-onboarding-start-posting-options",
        ({ value }) => {
          value.push(
            class ExtraOption extends StartPostingOption {
              @service appEvents;

              name = "extra-option";
              title = "admin_onboarding_banner.start_posting.extra_option";
              body =
                "admin_onboarding_banner.start_posting.extra_option_description";

              @action
              onSelect() {
                this.appEvents.trigger("admin-onboarding:posting-complete");
                this.args.closeModal();
              }
            }
          );
          return value;
        }
      );
    });

    const step = withStep("start_posting", assert);
    await visit("/");

    step.isNotChecked();

    await step.clickAction();

    assert.dom(".start-posting-options-modal__card").exists({ count: 2 });
    await click(".start-posting-options-modal__card.extra-option");

    step.isChecked();
  });

  test("registered posting-option can be disabled when step is complete", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer(
        "admin-onboarding-start-posting-options",
        ({ value }) => {
          value.push(
            class CompletingOption extends StartPostingOption {
              @service appEvents;

              name = "completing-option";
              title = "admin_onboarding_banner.start_posting.extra_option";
              body =
                "admin_onboarding_banner.start_posting.extra_option_description";

              @action
              onSelect() {
                this.appEvents.trigger("admin-onboarding:posting-complete");
                this.args.closeModal();
              }
            }
          );

          value.push(
            class HideableOption extends StartPostingOption {
              name = "hideable-option";
              title = "admin_onboarding_banner.start_posting.extra_option";
              body =
                "admin_onboarding_banner.start_posting.extra_option_description";

              get disableAction() {
                return this.args.isComplete;
              }

              @action
              onSelect() {}
            }
          );

          return value;
        }
      );
    });

    await visit("/");

    await withStep("start_posting", assert).clickAction();

    assert.dom(".start-posting-options-modal__card").exists({ count: 3 });
    assert
      .dom(".start-posting-options-modal__card.hideable-option")
      .isNotDisabled("card is enabled before step completion");

    await click(".start-posting-options-modal__card.completing-option");

    await withStep("start_posting", assert).clickAction();

    assert
      .dom(".start-posting-options-modal__card.hideable-option")
      .isDisabled("card is disabled after step completion");
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
      .dom(".design-wizard-float")
      .exists("the design wizard slides in as a sheet");
    assert
      .dom(".design-wizard-modal__theme-card")
      .exists({ count: 2 }, "the theme step shows Foundation and Horizon");
    assert
      .dom(".design-wizard-modal__theme-card.--selected")
      .hasAttribute("data-theme-id", "-1", "preselects the default theme");
    assert
      .dom(".sidebar-design-wizard__back")
      .isDisabled("cannot go back from the first step");

    await click(".sidebar-design-wizard__next");
    assert
      .dom(".design-wizard-modal__theme-card")
      .doesNotExist("theme cards are left behind on the colors step");
    assert
      .dom(".design-wizard-modal__swatch")
      .exists({ count: 1 }, "the colors step shows the theme's palette pairs");

    await click(".design-wizard-modal__swatch[data-pair-key='default']");
    assert
      .dom("link[data-scheme-id]", document.documentElement)
      .exists("the page's color scheme stylesheet is swapped for the preview");

    assert
      .dom(".design-wizard-modal__font-select")
      .exists({ count: 2 }, "the colors step offers the font dropdowns");

    await click(".sidebar-design-wizard__next");
    assert
      .dom(".design-wizard-modal__homepage-card")
      .exists({ count: 2 }, "the homepage step offers topics and categories");
    assert
      .dom(".design-wizard-modal__homepage-card.--selected")
      .hasAttribute("data-homepage", "topics", "defaults to a topics homepage");
    assert
      .dom(".design-wizard-modal__topic-page-select")
      .exists("a topics homepage offers the topic page types");

    await click(
      ".design-wizard-modal__homepage-card[data-homepage='categories']"
    );
    assert
      .dom(".design-wizard-modal__style-block")
      .exists({ count: 3 }, "a categories homepage offers the page styles");
    assert
      .dom(".design-wizard-modal__style-block.--selected")
      .hasAttribute(
        "data-style",
        "categories_boxes",
        "defaults to boxes with subcategories"
      );
    assert
      .dom(".design-wizard-modal__topic-page-select")
      .doesNotExist("the topic page types are hidden for categories");

    assert
      .dom(".sidebar-design-wizard__next")
      .doesNotExist("no next on the last step");
    assert
      .dom(".sidebar-design-wizard__save")
      .exists("the last step offers save");

    await click(".sidebar-design-wizard__back");
    assert
      .dom(".design-wizard-modal__swatch")
      .exists({ count: 1 }, "back returns to the colors step");

    await click(".design-wizard-float__close");
    assert
      .dom(".design-wizard-float")
      .doesNotExist("closing removes the sheet");
    assert
      .dom("link[data-scheme-id]", document.documentElement)
      .doesNotExist("the palette preview is reverted");

    // previewing a categories homepage routed away from the banner's page
    await visit("/");
    step.isNotChecked();
  });
});

acceptance("Admin - Onboarding Banner - admin invites", function (needs) {
  needs.user({
    admin: true,
    groups: [AUTO_GROUPS.admins],
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
    groups: [AUTO_GROUPS.admins],
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
