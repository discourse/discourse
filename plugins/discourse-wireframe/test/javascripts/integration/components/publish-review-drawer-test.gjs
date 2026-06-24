import Service from "@ember/service";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import PublishReviewDrawer from "discourse/plugins/discourse-wireframe/discourse/components/editor/publish-review-drawer";

/**
 * A permissive stub of the wireframe service driving just the surface the drawer
 * reads, so a single stub can back several publish-plan scenarios. Config sets
 * the publish targets, the active theme target, and a per-outlet change summary.
 */
class StubWireframeService extends Service {
  isActive = true;
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

  get publishTargets() {
    return this.#config.publishTargets ?? [];
  }

  get activeThemeTarget() {
    return this.#config.activeThemeTarget ?? null;
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
}

function stubWireframe(owner, config) {
  owner.unregister("service:wireframe");
  owner.register("service:wireframe", new StubWireframeService(owner, config), {
    instantiate: false,
  });
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
