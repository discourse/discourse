import { action } from "@ember/object";
import { service } from "@ember/service";
import { click, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import StartPostingOption from "discourse/components/admin-onboarding/start-posting-option";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Admin - Onboarding Banner", function (needs) {
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

  needs.pretender((server, helper) => {
    server.put("/admin/site_settings/enable_site_owner_onboarding", () => {
      return helper.response(200, {
        success: "OK",
      });
    });

    server.post("/invites", () => {
      return helper.response(200, {
        success: "OK",
      });
    });

    server.get("/admin/themes.json", () => {
      return helper.response(200, {
        themes: [
          {
            id: -1,
            name: "Foundation",
            default: true,
            screenshot_light_url: null,
            screenshot_dark_url: null,
          },
          {
            id: -2,
            name: "Horizon",
            default: false,
            screenshot_light_url: null,
            screenshot_dark_url: null,
          },
        ],
        extras: { color_schemes: [] },
      });
    });

    server.put("/admin/themes/-2.json", () => {
      return helper.response(200, {
        theme: { id: -2, name: "Horizon", default: true },
      });
    });
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

  test("it shows onboarding banner", async function (assert) {
    await visit("/");
    assert.dom(".admin-onboarding-banner").exists("shows onboarding banner");
  });

  test("it can end onboarding prematurely", async function (assert) {
    await visit("/");
    assert.dom(".admin-onboarding-banner").exists();

    await click(".admin-onboarding-banner .btn-close");
    assert.dom(".admin-onboarding-banner").doesNotExist();
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
  });

  test("it can open `select_theme` step", async function (assert) {
    const step = withStep("select_theme", assert);

    await visit("/");

    step.isNotChecked();
    await step.clickAction();
    await settled();

    assert.dom(".theme-picker-modal").exists("theme picker modal is shown");
    assert
      .dom(".theme-picker-modal__card")
      .exists({ count: 2 }, "shows Foundation and Horizon");
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
