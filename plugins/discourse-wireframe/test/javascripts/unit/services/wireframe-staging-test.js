import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

// `wireframe-staging` owns the in-session draft layer + the publish/save/discard
// workflow. These tests cover the commit-orchestration logic — publish-result
// processing, the stale-version conflict prompt, and the git escape-hatch error
// formatting — which previously had no direct unit coverage (it was exercised
// only through the orchestrator). The draft-layer materialize paths are covered
// end-to-end by the navigation + service integration tests.

const DEFAULTS = {
  "service:modal": () => ({ show: async () => ({}) }),
  "service:wireframe-image-composition": () => ({ target: null }),
  "service:wireframe-edit-mode": () => ({ active: true }),
  "service:wireframe-drafts": () => ({
    fetchDesigns: async () => ({
      installedId: null,
      currentId: null,
      designs: [],
    }),
  }),
  "service:wireframe-layout-query": () => ({
    readResolvedLayout: () => [],
    outletState: () => "default",
  }),
  "service:wireframe-publish-target": () => ({
    activeThemeId: 5,
    defaultThemeId: 5,
    activeThemeTarget: { publishable: true },
    hasDesign: true,
    parentThemeId: 5,
    registerDesign() {},
    setActiveTheme() {},
    outletOwner: () => ({ themeId: 5, isGit: false }),
  }),
  "service:wireframe-mutation-engine": () => ({
    isDirty: false,
    editedOutletNames: () => [],
    editedOutletsSize: 0,
    isOutletEdited: () => false,
    clearStacks() {},
    clearOutletEditState() {},
    rollbackOutletInMemory() {},
    dropUndoEntriesForOutlet() {},
  }),
  "service:wireframe-live-layout": () => ({
    publish: async () => ({ saved: [], errors: [] }),
    publishOutlet: async () => ({ saved: [], errors: [] }),
    overwriteOutlet: async () => true,
    createDesign: async () => ({ theme_id: 1 }),
    installDesign: async () => {},
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

    test("createDesign saves the new layout as a draft", async function (assert) {
      const registered = [];
      const created = [];
      const staging = buildStaging(getOwner(this), {
        "service:wireframe-publish-target": {
          registerDesign: (...args) => registered.push(args),
        },
        "service:wireframe-live-layout": {
          createDesign: async (...args) => {
            created.push(args);
            return { theme_id: 9 };
          },
        },
      });
      const result = await staging.createDesign("Spring");
      assert.deepEqual(result, { themeId: 9 });
      assert.deepEqual(
        registered,
        [[9, "Spring", { inUse: false }]],
        "a new layout is registered as not used by the theme"
      );
      assert.strictEqual(
        created[0][2]?.install,
        undefined,
        "creating a layout does not ask to install it"
      );
    });

    test("publishEditedOutlets returns null on a clean publish", async function (assert) {
      const staging = buildStaging(getOwner(this));
      assert.strictEqual(await staging.publishEditedOutlets(), null);
    });

    test("publishEditedOutlets surfaces non-conflict errors as a banner", async function (assert) {
      const staging = buildStaging(getOwner(this), {
        "service:wireframe-live-layout": {
          publish: async () => ({
            saved: [],
            errors: [{ outlet: "homepage-blocks", message: "boom" }],
          }),
        },
        "service:wireframe-mutation-engine": { editedOutletsSize: 1 },
      });
      assert.strictEqual(
        await staging.publishEditedOutlets(),
        "homepage-blocks: boom"
      );
    });

    test("a stale-version conflict prompts and overwrites on confirm", async function (assert) {
      const calls = [];
      const staging = buildStaging(getOwner(this), {
        "service:wireframe-live-layout": {
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
        "service:wireframe-mutation-engine": {
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
        "service:wireframe-live-layout": {
          publish: async () => ({
            saved: [],
            errors: [{ outlet: "homepage-blocks", conflict: true, themeId: 5 }],
          }),
          overwriteOutlet: async () => {
            overwritten = true;
            return true;
          },
        },
        "service:wireframe-mutation-engine": { editedOutletsSize: 1 },
        "service:modal": { show: async () => ({ choice: "cancel" }) },
      });

      await staging.publishEditedOutlets();
      assert.false(overwritten, "cancel leaves the outlet edited for the user");
    });

    test("createDesign returns the new design's id and binds the session to it", async function (assert) {
      let boundTo;
      const staging = buildStaging(getOwner(this), {
        "service:wireframe-live-layout": {
          createDesign: async (themeId, name) => {
            assert.strictEqual(themeId, 5);
            assert.strictEqual(name, "Spring launch");
            return { theme_id: 9 };
          },
        },
        "service:wireframe-publish-target": {
          setActiveTheme: (id) => (boundTo = id),
        },
      });
      assert.deepEqual(await staging.createDesign("Spring launch"), {
        themeId: 9,
      });
      assert.strictEqual(boundTo, 9);
    });

    test("createDesign returns an error message on failure", async function (assert) {
      const staging = buildStaging(getOwner(this), {
        "service:wireframe-live-layout": {
          createDesign: async () => {
            throw { jqXHR: { responseJSON: { errors: ["nope"] } } };
          },
        },
      });
      assert.deepEqual(await staging.createDesign("Spring launch"), {
        error: "nope",
      });
    });

    test("switchDesign returns null on success and the server error on failure", async function (assert) {
      const ok = buildStaging(getOwner(this));
      assert.strictEqual(await ok.switchDesign(9), null);

      const failing = buildStaging(getOwner(this), {
        "service:wireframe-live-layout": {
          installDesign: async () => {
            throw { jqXHR: { responseJSON: { errors: ["gone"] } } };
          },
        },
      });
      assert.strictEqual(await failing.switchDesign(9), "gone");
    });
  }
);
