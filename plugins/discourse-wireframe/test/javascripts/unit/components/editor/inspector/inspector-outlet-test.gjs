import Service from "@ember/service";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import InspectorPanel from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/inspector-panel";

/**
 * A permissive stub for the wireframe service. Only the surface the inspector
 * panel (and the layout form it renders for an outlet root) reads is
 * implemented; everything returns a safe default so a single stub can back
 * several different renders. `isOutletRoot` is driven off the block data so a
 * test can flip a selection into "this is the outlet" mode.
 */
class StubWireframeService extends Service {
  #blockData;

  constructor(owner, blockData) {
    super(owner);
    this.#blockData = blockData;
  }

  // The stub is registered as service:wireframe-layout-query too, so a
  // component injecting wireframeLayoutQuery resolves these query methods.
  get layoutQuery() {
    return this;
  }

  get selectedBlockData() {
    return this.#blockData;
  }

  get selectedBlockKey() {
    return this.#blockData?.key ?? "wf:stub:1";
  }

  get selectedBlockFieldErrors() {
    return {};
  }

  get selectedBlockNonFieldErrors() {
    return [];
  }

  get selectedBlockHasErrors() {
    return false;
  }

  get conditionsDetached() {
    return false;
  }

  isOutletRoot() {
    return this.#blockData?.isOutletRoot === true;
  }

  // Surface the layout form (rendered for the outlet root, whose block name is
  // "layout") reads. Safe defaults keep the form inert.
  canApplyGridTemplate() {
    return false;
  }

  activeGridTemplate() {
    return null;
  }

  gridSizeFor() {
    return { columns: 3, rows: 2 };
  }

  applyFreeGrid() {}

  outOfBoundsSlotsIn() {
    return [];
  }

  updateSelectedArg() {}

  partLockForSelection() {
    return null;
  }

  toggleConditionsDetached() {}

  // Surface the per-outlet section (rendered for an outlet root) reads. Safe
  // defaults: a default, editable, non-Git outlet with no unsaved edits; a test
  // can drive the state/owner through `blockData`.
  outletState() {
    return this.#blockData?.outletState ?? "default";
  }

  outletOwner() {
    return (
      this.#blockData?.outletOwner ?? {
        themeId: null,
        themeName: null,
        isGit: false,
      }
    );
  }

  isOutletEdited() {
    return this.#blockData?.isOutletEditing ?? false;
  }
}

function stubWireframe(owner, blockData) {
  const stub = new StubWireframeService(owner, blockData);
  owner.unregister("service:wireframe-workspace");
  owner.register("service:wireframe-workspace", stub, { instantiate: false });
  owner.unregister("service:wireframe-selection");
  owner.register("service:wireframe-selection", stub, { instantiate: false });
  owner.unregister("service:wireframe-layout-query");
  owner.register("service:wireframe-layout-query", stub, {
    instantiate: false,
  });
  // The layout form reads grid-shape helpers + writes args through the peer
  // services; point them at the same stub so its inert defaults/recorders apply.
  owner.unregister("service:wireframe-grid-template");
  owner.register("service:wireframe-grid-template", stub, {
    instantiate: false,
  });
  owner.unregister("service:wireframe-inspector-args");
  owner.register("service:wireframe-inspector-args", stub, {
    instantiate: false,
  });
  // The per-outlet section reads its editing flag from the mutation engine.
  owner.unregister("service:wireframe-mutation-engine");
  owner.register("service:wireframe-mutation-engine", stub, {
    instantiate: false,
  });
}

module(
  "Integration | Wireframe | Inspector | friendly outlet & block names",
  function (hooks) {
    setupRenderingTest(hooks);

    test("an outlet root shows the friendly outlet name and description", async function (assert) {
      // The implicit root layout IS the outlet; the inspector presents it as
      // the outlet, not as a "layout" block. The friendly name + description
      // come from the real outlet registry (CORE_OUTLET_METADATA).
      stubWireframe(this.owner, {
        name: "layout",
        isOutletRoot: true,
        outletName: "homepage-blocks",
        args: { mode: "stack" },
        argsSnapshot: { mode: "stack" },
        parentChildArgsSchema: null,
      });

      await render(<template><InspectorPanel /></template>);

      assert
        .dom(".wireframe-inspector__block-name")
        .hasText(
          "Homepage",
          "the header shows the outlet's display name, not the 'layout' block name"
        );
      assert
        .dom(".wireframe-inspector__metadata-info")
        .exists("the info icon is present for an outlet with a description")
        .hasAttribute(
          "title",
          "The main content area of the site homepage.",
          "the tooltip describes the outlet, not the layout block"
        );
    });

    test("a registered block shows its friendly display name", async function (assert) {
      stubWireframe(this.owner, {
        name: "wf:heading",
        isRegistered: true,
        metadata: {
          displayName: "Heading",
          shortName: "heading",
          args: { title: { type: "string" } },
        },
        args: { title: "Hello" },
        argsSnapshot: { title: "Hello" },
        parentChildArgsSchema: null,
      });

      await render(<template><InspectorPanel /></template>);

      assert
        .dom(".wireframe-inspector__block-name")
        .hasText(
          "Heading",
          "the header prefers the block's friendly displayName over the raw name"
        );
    });

    test("an unregistered block falls back to its raw name", async function (assert) {
      stubWireframe(this.owner, {
        name: "wf:gone",
        isRegistered: false,
        metadata: null,
        args: { title: "Hello" },
        argsSnapshot: { title: "Hello" },
        parentChildArgsSchema: null,
      });

      await render(<template><InspectorPanel /></template>);

      assert
        .dom(".wireframe-inspector__block-name")
        .hasText(
          "wf:gone",
          "with no metadata there's no friendly name, so the raw name shows"
        );
    });

    test("the status shows a single badge with Editing superseding the state", async function (assert) {
      function outletRoot(extra) {
        return {
          name: "layout",
          isOutletRoot: true,
          outletName: "homepage-blocks",
          outletState: "default",
          args: { mode: "stack" },
          argsSnapshot: { mode: "stack" },
          parentChildArgsSchema: null,
          ...extra,
        };
      }

      stubWireframe(
        this.owner,
        outletRoot({
          outletState: "published",
          outletOwner: { themeId: 5, themeName: "Acme", isGit: false },
          isOutletEditing: true,
        })
      );

      await render(<template><InspectorPanel /></template>);

      assert
        .dom(".wireframe-inspector__outlet-state .wireframe-outlet-badge")
        .exists({ count: 1 }, "exactly one status badge, not state + editing");
      assert
        .dom(".wireframe-inspector__outlet-state .wireframe-outlet-badge")
        .hasText("Editing", "Editing supersedes the published state");
    });
  }
);
