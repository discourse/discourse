import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

// `wireframe-staging` owns the in-session draft layer + the publish/save/discard
// workflow. These tests cover the commit-orchestration logic — publish-result
// processing, the stale-version conflict prompt, and the git escape-hatch error
// formatting — which previously had no direct unit coverage (it was exercised
// only through the kernel). The draft-layer materialize/hydrate paths are covered
// end-to-end by the navigation + service integration tests.

// Minimal stubs for the nine peers the staging service injects. Each test
// overrides only the methods it asserts on; everything else is an inert default
// so a single lookup can back several scenarios.
const DEFAULTS = {
  "service:modal": () => ({ show: async () => ({}) }),
  "service:wireframe-arg-edit": () => ({ hasPending: false }),
  "service:wireframe-inline-edit": () => ({ blockKey: null }),
  "service:wireframe-session": () => ({ active: true }),
  "service:wireframe-drafts": () => ({
    deleteDraft: async () => {},
    saveDraftOutlet: async () => {},
    fetchDrafts: async () => [],
    companionId: async () => null,
  }),
  "service:wireframe-layout-query": () => ({
    readResolvedLayout: () => [],
    outletState: () => "default",
  }),
  "service:wireframe-theme": () => ({
    activeThemeId: 5,
    defaultThemeId: 5,
    activeThemeTarget: { publishable: true },
    outletOwner: () => ({ themeId: 5, isGit: false }),
  }),
  "service:wireframe-edit-engine": () => ({
    isDirty: false,
    editedOutletNames: () => [],
    editedOutletsSize: 0,
    isOutletEdited: () => false,
    clearStacks() {},
    clearOutletEditState() {},
    rollbackOutletInMemory() {},
    dropUndoEntriesForOutlet() {},
  }),
  "service:wireframe-persistence": () => ({
    publish: async () => ({ saved: [], errors: [] }),
    publishOutlet: async () => ({ saved: [], errors: [] }),
    overwriteOutlet: async () => true,
    exportOutlet: async () => {},
    duplicateTheme: async () => ({ theme_id: 1 }),
    createCustomizationComponent: async () => ({ theme_id: 1 }),
    resetToDefault: async () => {},
    tokenFor: () => "",
  }),
};

function buildStaging(owner, overrides = {}) {
  for (const [id, make] of Object.entries(DEFAULTS)) {
    const stub = { ...make(), ...(overrides[id] ?? {}) };
    owner.unregister(id);
    owner.register(id, stub, { instantiate: false });
  }
  owner.unregister("service:wireframe-staging");
  return owner.lookup("service:wireframe-staging");
}

module(
  "Unit | Discourse Wireframe | service:wireframe-staging",
  function (hooks) {
    setupTest(hooks);

    test("openReviewDrawer / closeReviewDrawer toggle the drawer", function (assert) {
      const staging = buildStaging(getOwner(this));
      assert.false(staging.reviewDrawerOpen);
      staging.openReviewDrawer();
      assert.true(staging.reviewDrawerOpen);
      staging.closeReviewDrawer();
      assert.false(staging.reviewDrawerOpen);
    });

    test("canOpenReview is true when the engine is dirty", function (assert) {
      const staging = buildStaging(getOwner(this), {
        "service:wireframe-edit-engine": { isDirty: true },
      });
      assert.true(staging.canOpenReview);
    });

    test("canOpenReview is false with nothing dirty and no unsaved drafts", function (assert) {
      const staging = buildStaging(getOwner(this));
      assert.false(staging.canOpenReview);
    });

    test("publishEditedOutlets returns null on a clean publish", async function (assert) {
      const staging = buildStaging(getOwner(this));
      assert.strictEqual(await staging.publishEditedOutlets(), null);
    });

    test("publishEditedOutlets surfaces non-conflict errors as a banner", async function (assert) {
      const staging = buildStaging(getOwner(this), {
        "service:wireframe-persistence": {
          publish: async () => ({
            saved: [],
            errors: [{ outlet: "homepage-blocks", message: "boom" }],
          }),
        },
        "service:wireframe-edit-engine": { editedOutletsSize: 1 },
      });
      assert.strictEqual(
        await staging.publishEditedOutlets(),
        "homepage-blocks: boom"
      );
    });

    test("a stale-version conflict prompts and overwrites on confirm", async function (assert) {
      const calls = [];
      const staging = buildStaging(getOwner(this), {
        "service:wireframe-persistence": {
          publish: async () => ({
            saved: [],
            errors: [
              {
                outlet: "homepage-blocks",
                conflict: true,
                themeId: 5,
                currentVersion: "v2",
              },
            ],
          }),
          overwriteOutlet: async (outlet, themeId, version) => {
            calls.push(["overwrite", outlet, themeId, version]);
            return true;
          },
        },
        "service:wireframe-edit-engine": {
          editedOutletsSize: 0,
          clearOutletEditState: (outlet) => calls.push(["clear", outlet]),
        },
        "service:modal": { show: async () => ({ choice: "overwrite" }) },
      });

      // Conflicts aren't "other errors", so the banner is null even though one
      // outlet conflicted.
      assert.strictEqual(await staging.publishEditedOutlets(), null);
      assert.deepEqual(calls, [
        ["overwrite", "homepage-blocks", 5, "v2"],
        ["clear", "homepage-blocks"],
      ]);
    });

    test("a dismissed conflict does not overwrite", async function (assert) {
      let overwritten = false;
      const staging = buildStaging(getOwner(this), {
        "service:wireframe-persistence": {
          publish: async () => ({
            saved: [],
            errors: [{ outlet: "homepage-blocks", conflict: true, themeId: 5 }],
          }),
          overwriteOutlet: async () => {
            overwritten = true;
            return true;
          },
        },
        "service:wireframe-edit-engine": { editedOutletsSize: 1 },
        "service:modal": { show: async () => ({ choice: "cancel" }) },
      });

      await staging.publishEditedOutlets();
      assert.false(overwritten, "cancel leaves the outlet edited for the user");
    });

    test("exportOutlet returns null on success", async function (assert) {
      const staging = buildStaging(getOwner(this));
      assert.strictEqual(await staging.exportOutlet("homepage-blocks"), null);
    });

    test("exportOutlet returns the server's error as a banner on failure", async function (assert) {
      const staging = buildStaging(getOwner(this), {
        "service:wireframe-persistence": {
          exportOutlet: async () => {
            throw { jqXHR: { responseJSON: { errors: ["no repo"] } } };
          },
        },
      });
      assert.strictEqual(
        await staging.exportOutlet("homepage-blocks"),
        "no repo"
      );
    });

    test("duplicateForEditing returns the new theme id on success", async function (assert) {
      const staging = buildStaging(getOwner(this), {
        "service:wireframe-persistence": {
          duplicateTheme: async () => ({ theme_id: 9 }),
        },
      });
      assert.deepEqual(await staging.duplicateForEditing(), { themeId: 9 });
    });

    test("duplicateForEditing returns an error message on failure", async function (assert) {
      const staging = buildStaging(getOwner(this), {
        "service:wireframe-persistence": {
          duplicateTheme: async () => {
            throw { jqXHR: { responseJSON: { errors: ["nope"] } } };
          },
        },
      });
      assert.deepEqual(await staging.duplicateForEditing(), { error: "nope" });
    });
  }
);
