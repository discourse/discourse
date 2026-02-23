import { click, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Admin - Onboarding Banner", function (needs) {
  needs.user({
    admin: true,
    groups: [AUTO_GROUPS.admins],
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
  });

  needs.hooks.beforeEach(() => {
    const mockClipboard = {
      writeText: sinon.stub().resolves(true),
      write: sinon.stub().resolves(true),
    };
    sinon.stub(window.navigator, "clipboard").get(() => mockClipboard);
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
    this.siteSettings.enable_site_owner_onboarding = false;

    await settled();
    assert.dom(".admin-onboarding-banner").doesNotExist();
  });

  test("it can complete `start_posting` step with predefined data", async function (assert) {
    this.siteSettings.discourse_ai_enabled = false;

    const step = withStep("start_posting", assert);
    await visit("/");

    step.isNotChecked();

    await step.clickAction();

    assert.dom(".predefined-topic-options-modal__card").exists({ count: 4 });
    await click(
      ".predefined-topic-options-modal__card:last-child .predefined-topic-options-modal__select-btn"
    );

    await click(".create");
    await visit("/");

    step.isChecked();
  });

  test("it can complete `start_posting` step with AI generated content", async function (assert) {
    this.siteSettings.discourse_ai_enabled = true;

    const step = withStep("start_posting", assert);
    await visit("/");

    step.isNotChecked();

    await step.clickAction();
    await click(".ai-option .btn");

    const appEvents = this.owner.lookup("service:app-events");
    appEvents.on("admin-onboarding:select-ai", () => {
      assert.ok(true, "triggers admin-onboarding:select-ai event");
      appEvents.trigger("topic:created");
      step.isChecked();
    });
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

  test("it can complete `spread_the_word` step", async function (assert) {
    const step = withStep("spread_the_word", assert);

    await visit("/");

    step.isNotChecked();
    await step.clickAction();
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
