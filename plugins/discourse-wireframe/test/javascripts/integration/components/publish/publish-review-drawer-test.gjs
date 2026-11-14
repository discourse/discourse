import Service from "@ember/service";
import {
  click,
  findAll,
  focus,
  render,
  triggerKeyEvent,
} from "@ember/test-helpers";
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

  createdDesigns = [];

  switched = [];

  navigatedToThemeInUse = false;

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

  get designInUse() {
    return this.#config.designInUse ?? true;
  }

  get designName() {
    return this.#config.designName ?? "Untitled template";
  }

  get hasDesign() {
    return this.#config.activeThemeTarget?.publishable ?? false;
  }

  switchDesign(designId) {
    this.switched.push(designId);
    return null;
  }

  markDesignInUse() {}

  navigateToThemeInUse() {
    this.navigatedToThemeInUse = true;
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

  createDesign(name) {
    this.createdDesigns.push(name);
    return { themeId: 9 };
  }

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

    test("DTabs adoption supports manual keyboard activation", async function (assert) {
      stubWireframe(this.owner, {});

      await render(<template><PublishReviewDrawer /></template>);

      const [details, changes] = findAll(".wireframe-review__tab");
      await focus(details);
      await triggerKeyEvent(details, "keydown", "ArrowRight");
      assert.dom(changes).isFocused("arrows move focus to Changes");
      assert
        .dom(details)
        .hasAttribute("aria-selected", "true", "focus does not activate a tab");

      await triggerKeyEvent(changes, "keydown", "Enter");
      assert
        .dom(changes)
        .hasAttribute("aria-selected", "true", "Enter activates Changes");
      assert
        .dom(".wireframe-review__empty")
        .exists({ count: 1 }, "only the active panel's content is mounted");
      assert
        .dom(".wireframe-review__group")
        .doesNotExist("inactive content is unmounted");
      assert
        .dom(".wireframe-review [role=tabpanel]")
        .hasAttribute(
          "aria-labelledby",
          changes.id,
          "the active tab labels the panel"
        );
    });

    test("a publishable theme renders a group that will publish, with Publish enabled", async function (assert) {
      stubWireframe(this.owner, {
        activeThemeTarget: {
          themeId: 5,
          themeName: "Acme",
          publishable: true,
        },
        publishTargets: [
          {
            themeId: 5,
            themeName: "Acme",
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
          publishable: true,
        },
        publishTargets: [
          {
            themeId: 5,
            themeName: "Acme",
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

    test("a theme with no design yet marks the edits as awaiting a name and creates one on Publish", async function (assert) {
      stubWireframe(this.owner, {
        activeThemeTarget: {
          themeId: -1,
          themeName: "Foundation",
          publishable: false,
        },
        publishTargets: [
          {
            themeId: -1,
            themeName: "Foundation",
            publishable: false,
            outlets: ["homepage-blocks"],
          },
        ],
      });
      await render(<template><PublishReviewDrawer /></template>);

      assert
        .dom(".wireframe-review__group-status.--pending")
        .exists("the group is awaiting a design name");
      assert
        .dom(
          ".wireframe-review__create-component, .wireframe-review__duplicate"
        )
        .doesNotExist("no theme-level escape hatches are offered");
      assert
        .dom(".wireframe-review__publish")
        .isNotDisabled("Publish stays available — it creates the design");

      await click(".wireframe-review__publish");

      assert.deepEqual(
        this.owner.lookup("service:wireframe-staging").createdDesigns,
        ["Untitled template"],
        "the design is created with the header's name"
      );
    });

    function stubHomepagePublish(owner, config = {}) {
      stubWireframe(owner, {
        homepageToggleAvailable: true,
        homepageThemeId: 42,
        renderableOutlets: ["homepage-blocks"],
        activeThemeTarget: {
          themeId: 9,
          themeName: "Spring",
          publishable: true,
        },
        publishTargets: [
          {
            themeId: 9,
            themeName: "Spring",
            publishable: true,
            outlets: ["homepage-blocks"],
          },
        ],
        ...config,
      });
    }

    test("publishing a design the theme doesn't use asks whether to use it", async function (assert) {
      stubHomepagePublish(this.owner, { designInUse: false });
      this.owner.lookup("service:site-settings").wireframe_custom_homepage =
        true;
      let prompt;
      this.owner.unregister("service:dialog");
      this.owner.register(
        "service:dialog",
        class extends Service {
          alert(params) {
            prompt = params;
            params.buttons[0].action();
          }
        }
      );

      await render(<template><PublishReviewDrawer /></template>);
      await click(".wireframe-review__publish");

      const staging = this.owner.lookup("service:wireframe-staging");
      assert.strictEqual(
        prompt.buttons.length,
        3,
        "offers use, publish only, and cancel"
      );
      assert.deepEqual(staging.switched, [5], "the design is put in use");
      assert.true(
        staging.navigatedToThemeInUse,
        "reloads onto what visitors see"
      );
    });

    test("there is no homepage toggle in the drawer", async function (assert) {
      stubHomepagePublish(this.owner);

      await render(<template><PublishReviewDrawer /></template>);

      assert.dom(".wireframe-review__homepage").doesNotExist();
    });

    test("publish switches the custom homepage on for the theme in use", async function (assert) {
      stubHomepagePublish(this.owner);
      const siteSettings = this.owner.lookup("service:site-settings");
      siteSettings.wireframe_custom_homepage = false;

      const putBodies = [];
      pretender.put("/admin/themes/:id/site-setting", (request) => {
        putBodies.push([request.params.id, request.requestBody]);
        return response({ success: "OK" });
      });

      await render(<template><PublishReviewDrawer /></template>);
      await click(".wireframe-review__publish");

      assert.deepEqual(
        putBodies,
        [["42", "name=wireframe_custom_homepage&value=true"]],
        "the setting write targets the theme in use with an explicit boolean"
      );
      assert.true(
        siteSettings.wireframe_custom_homepage,
        "the applied value is mirrored locally"
      );
    });

    test("publish leaves the homepage setting alone when it is already on or has no content", async function (assert) {
      pretender.put("/admin/themes/:id/site-setting", () => {
        assert.step("written");
        return response({ success: "OK" });
      });

      stubHomepagePublish(this.owner);
      this.owner.lookup("service:site-settings").wireframe_custom_homepage =
        true;
      await render(<template><PublishReviewDrawer /></template>);
      await click(".wireframe-review__publish");

      stubHomepagePublish(this.owner, { renderableOutlets: [] });
      this.owner.lookup("service:site-settings").wireframe_custom_homepage =
        false;
      await render(<template><PublishReviewDrawer /></template>);
      await click(".wireframe-review__publish");

      assert.verifySteps([]);
    });

    test("a failed homepage write keeps the drawer open", async function (assert) {
      stubHomepagePublish(this.owner);
      this.owner.lookup("service:site-settings").wireframe_custom_homepage =
        false;

      pretender.put("/admin/themes/:id/site-setting", () =>
        response(500, { errors: ["boom"] })
      );

      await render(<template><PublishReviewDrawer /></template>);
      await click(".wireframe-review__publish");

      assert
        .dom(".wireframe-review__error")
        .exists("the failure lands in the banner");
      assert
        .dom(".wireframe-review")
        .exists("the drawer stays open for a retry");
    });
  }
);
