import Service from "@ember/service";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import PublishReviewDrawer from "discourse/plugins/discourse-wireframe/discourse/components/editor/publish/publish-review-drawer";

/**
 * A permissive stub of the wireframe service driving just the surface the drawer
 * reads, so a single stub can back several publish-plan scenarios. Config sets
 * the publish targets, the active theme target, and a per-outlet change summary.
 */
class StubWireframeService extends Service {
  reviewDrawerOpen = true;

  isDirty = true;

  hasUnsavedDraftEdits = true;

  activeThemeId = 5;

  hasValidationWarnings = false;

  validationWarnings = [];

  #config;

  constructor(owner, config) {
    super(owner);
    this.#config = config;
  }

  // The stub is registered as service:wireframe-layout-query too, so a
  // component injecting wireframeLayoutQuery resolves these query methods.
  get layoutQuery() {
    return this;
  }

  get publishTargets() {
    return this.#config.publishTargets ?? [];
  }

  get activeThemeTarget() {
    return this.#config.activeThemeTarget ?? null;
  }

  get homepageToggleAvailable() {
    return this.#config.homepageToggleAvailable ?? false;
  }

  get homepageThemeId() {
    return this.#config.homepageThemeId ?? 5;
  }

  hasRenderableContent(name) {
    return this.#config.renderableOutlets?.includes(name) ?? false;
  }

  outletState(name) {
    return this.#config.outletStates?.[name] ?? "default";
  }

  outletChangeSummary() {
    return (
      this.#config.changeSummary ?? {
        added: 0,
        removed: 0,
        moved: 0,
        edited: 0,
        reliable: true,
      }
    );
  }

  outletLayoutJson() {
    return "[]";
  }

  closeReviewDrawer() {}
  discardAll() {}
  saveAllEditedDrafts() {}
  publishEditedOutlets() {}
  resetToDefault() {}
  exportOutlet() {}
  createCustomizationComponent() {
    return {};
  }

  duplicateForEditing() {
    return {};
  }

  navigateToEditTheme() {}

  exit() {}
}

function stubWireframe(owner, config) {
  owner.unregister("service:wireframe-workspace");
  const stub = new StubWireframeService(owner, config);
  owner.register("service:wireframe-workspace", stub, { instantiate: false });
  owner.unregister("service:wireframe-layout-query");
  owner.register("service:wireframe-layout-query", stub, {
    instantiate: false,
  });
  // The drawer reads the publish plan (publishTargets / activeThemeTarget /
  // activeThemeId) off the publish-target service, so back it with the same stub instance.
  owner.unregister("service:wireframe-publish-target");
  owner.register("service:wireframe-publish-target", stub, {
    instantiate: false,
  });
  // The drawer reads the draft state + publish/save/discard workflow off the
  // staging service, so back it with the same stub instance.
  owner.unregister("service:wireframe-staging");
  owner.register("service:wireframe-staging", stub, { instantiate: false });
  // The drawer reads session state off the session signal service, not the
  // wireframe stub, so flip it active to mirror an open editor.
  owner.lookup("service:wireframe-edit-mode").activate();
}

module(
  "Integration | discourse-wireframe | Component | publish review drawer",
  function (hooks) {
    setupRenderingTest(hooks);

    test("a publishable theme renders a group that will publish, with Publish enabled", async function (assert) {
      stubWireframe(this.owner, {
        activeThemeTarget: {
          themeId: 5,
          themeName: "Acme",
          isGit: false,
          isSystem: false,
          publishable: true,
        },
        publishTargets: [
          {
            themeId: 5,
            themeName: "Acme",
            isGit: false,
            isSystem: false,
            publishable: true,
            outlets: ["homepage-blocks"],
          },
        ],
      });

      await render(<template><PublishReviewDrawer /></template>);

      assert.dom(".wireframe-review").exists("the drawer renders");
      assert
        .dom(".wireframe-review__group-status.--ok")
        .exists("the group is marked publishable");
      assert
        .dom(".wireframe-review__create-component")
        .doesNotExist("no escape hatch for a publishable theme");
      assert
        .dom(".wireframe-review__publish")
        .isNotDisabled("Publish is enabled with a publishable target");
    });

    test("a published outlet on a publishable theme offers Reset to default", async function (assert) {
      stubWireframe(this.owner, {
        activeThemeTarget: {
          themeId: 5,
          themeName: "Acme",
          isGit: false,
          isSystem: false,
          publishable: true,
        },
        publishTargets: [
          {
            themeId: 5,
            themeName: "Acme",
            isGit: false,
            isSystem: false,
            publishable: true,
            outlets: ["homepage-blocks"],
          },
        ],
        outletStates: { "homepage-blocks": "published" },
      });

      await render(<template><PublishReviewDrawer /></template>);

      assert
        .dom(".wireframe-review__reset")
        .exists("a published, publishable outlet can be reset");
    });

    test("a Git theme offers create-component, duplicate, and per-outlet export with Publish disabled", async function (assert) {
      stubWireframe(this.owner, {
        activeThemeTarget: {
          themeId: 7,
          themeName: "Imported",
          isGit: true,
          isSystem: false,
          publishable: false,
        },
        publishTargets: [
          {
            themeId: 7,
            themeName: "Imported",
            isGit: true,
            isSystem: false,
            publishable: false,
            outlets: ["homepage-blocks"],
          },
        ],
      });

      await render(<template><PublishReviewDrawer /></template>);

      assert
        .dom(".wireframe-review__create-component")
        .exists("offers a companion component");
      assert
        .dom(".wireframe-review__duplicate")
        .exists("offers duplicate for a Git theme");
      assert
        .dom(".wireframe-review__export")
        .exists("offers per-outlet export for a Git theme");
      assert
        .dom(".wireframe-review__group-status.--blocked")
        .exists("the group is marked blocked");
      assert
        .dom(".wireframe-review__publish")
        .isDisabled("Publish is disabled when no target is publishable");
    });

    test("the homepage toggle is hidden when the opt-in isn't available", async function (assert) {
      stubWireframe(this.owner, {
        publishTargets: [
          {
            themeId: 5,
            themeName: "Acme",
            isGit: false,
            isSystem: false,
            publishable: true,
            outlets: ["homepage-blocks"],
          },
        ],
      });

      await render(<template><PublishReviewDrawer /></template>);

      assert.dom(".wireframe-review__homepage").doesNotExist();
    });

    test("the homepage toggle can't switch on while the homepage layout is empty", async function (assert) {
      stubWireframe(this.owner, {
        homepageToggleAvailable: true,
        renderableOutlets: [],
      });
      this.owner.lookup("service:site-settings").wireframe_custom_homepage =
        false;

      await render(<template><PublishReviewDrawer /></template>);

      assert
        .dom(".wireframe-review__homepage .d-toggle-switch__checkbox")
        .isDisabled("the switch is disabled with nothing to render");
      assert
        .dom(".wireframe-review__homepage-hint")
        .exists("the disabled reason is explained");
      assert
        .dom(".wireframe-review__publish")
        .isDisabled("nothing is pending, so Publish stays disabled");
    });

    test("flipping the homepage toggle stages the choice and enables Publish", async function (assert) {
      stubWireframe(this.owner, {
        homepageToggleAvailable: true,
        renderableOutlets: ["homepage-blocks"],
      });
      this.owner.lookup("service:site-settings").wireframe_custom_homepage =
        false;

      await render(<template><PublishReviewDrawer /></template>);

      assert
        .dom(".wireframe-review__publish")
        .isDisabled("nothing is staged yet");

      await click(".wireframe-review__homepage .d-toggle-switch__checkbox");

      assert
        .dom(".wireframe-review__homepage .d-toggle-switch__checkbox")
        .hasAria("checked", "true", "the switch reflects the staged choice");
      assert
        .dom(".wireframe-review__homepage-hint")
        .exists("the pending choice is explained");
      assert
        .dom(".wireframe-review__publish")
        .isNotDisabled("a staged homepage choice makes Publish available");
    });

    test("publish applies the staged homepage choice for the rendered theme", async function (assert) {
      stubWireframe(this.owner, {
        homepageToggleAvailable: true,
        homepageThemeId: 42,
        renderableOutlets: ["homepage-blocks"],
      });
      const siteSettings = this.owner.lookup("service:site-settings");
      siteSettings.wireframe_custom_homepage = false;

      const putBodies = [];
      pretender.put("/admin/themes/:id/site-setting", (request) => {
        putBodies.push([request.params.id, request.requestBody]);
        return response({ success: "OK" });
      });

      await render(<template><PublishReviewDrawer /></template>);
      await click(".wireframe-review__homepage .d-toggle-switch__checkbox");
      await click(".wireframe-review__publish");

      assert.deepEqual(
        putBodies,
        [["42", "name=wireframe_custom_homepage&value=true"]],
        "the setting write targets the rendered theme with an explicit boolean"
      );
      assert.true(
        siteSettings.wireframe_custom_homepage,
        "the applied value is mirrored locally"
      );
    });

    test("a failed homepage write keeps the drawer open with Publish still enabled", async function (assert) {
      stubWireframe(this.owner, {
        homepageToggleAvailable: true,
        homepageThemeId: 42,
        renderableOutlets: ["homepage-blocks"],
      });
      this.owner.lookup("service:site-settings").wireframe_custom_homepage =
        false;

      pretender.put("/admin/themes/:id/site-setting", () =>
        response(500, { errors: ["boom"] })
      );

      await render(<template><PublishReviewDrawer /></template>);
      await click(".wireframe-review__homepage .d-toggle-switch__checkbox");
      await click(".wireframe-review__publish");

      assert
        .dom(".wireframe-review__error")
        .exists("the failure lands in the banner");
      assert
        .dom(".wireframe-review")
        .exists("the drawer stays open for a retry");
      assert
        .dom(".wireframe-review__publish")
        .isNotDisabled("the staged choice keeps Publish available to retry");
    });

    test("a core system theme offers the companion component but not duplicate", async function (assert) {
      stubWireframe(this.owner, {
        activeThemeTarget: {
          themeId: -1,
          themeName: "Foundation",
          isGit: false,
          isSystem: true,
          publishable: false,
        },
        publishTargets: [
          {
            themeId: -1,
            themeName: "Foundation",
            isGit: false,
            isSystem: true,
            publishable: false,
            outlets: ["homepage-blocks"],
          },
        ],
      });

      await render(<template><PublishReviewDrawer /></template>);

      assert
        .dom(".wireframe-review__create-component")
        .exists("offers a companion component");
      assert
        .dom(".wireframe-review__duplicate")
        .doesNotExist("no duplicate for a core system theme");
      assert
        .dom(".wireframe-review__export")
        .doesNotExist("no per-outlet export for a core system theme");
    });
  }
);
