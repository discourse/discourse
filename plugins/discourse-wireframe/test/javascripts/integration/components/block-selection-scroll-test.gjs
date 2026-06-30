import { getOwner } from "@ember/owner";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import BlockChrome from "discourse/plugins/discourse-wireframe/discourse/components/editor/block-chrome";
import { setupBlockLayoutDraftsStub } from "../../helpers/stub-block-layout-drafts";

// Selecting a block scrolls its rendered element into view. The outline
// panel and insert auto-select both funnel through `wireframeSelection.selectBlock`,
// so exercising the service directly covers both entry points; what varies
// is the scroll decision, driven by the element's geometry.
const WrappedBlock = <template>
  <div data-block-arg="label">Block</div>
</template>;

module(
  "Integration | discourse-wireframe | block selection scroll",
  function (hooks) {
    setupRenderingTest(hooks);
    // The editor fetches the per-user drafts + companion endpoints on `enter()`;
    // stub them so the test doesn't hit an unhandled request.
    setupBlockLayoutDraftsStub(hooks);

    // QUnit's `#ember-testing-container` is an `overflow: auto` box that
    // horizontally overflows once a block renders inside it, so the reveal
    // logic's `#nearestInlineScroller` walk mistakes it for a real horizontal
    // scroller (a carousel track) and reports an on-screen block as horizontally
    // clipped — making the "already visible" case scroll. In production a plain
    // block has no such ancestor, so we relax the container's overflow for the
    // duration of each test to restore the real-world condition. The full
    // `overflow` shorthand is required: with `overflow-y` left at `auto`, a lone
    // `overflow-x: visible` computes back to `auto` per the CSS overflow spec.
    hooks.beforeEach(function () {
      this.testingContainer = document.getElementById(
        "ember-testing-container"
      );
      this.originalOverflow = this.testingContainer.style.overflow;
      this.testingContainer.style.overflow = "visible";
    });

    hooks.afterEach(function () {
      this.testingContainer.style.overflow = this.originalOverflow;
      getOwner(this).lookup("service:wireframe-workspace").exit();
    });

    // Renders a block chrome and returns the element carrying the block key
    // (the same node `selectBlock` looks up via `data-wf-block-key`), with a
    // stubbed bounding rect and a spy on its `scrollIntoView`.
    async function setupBlock(owner, rect) {
      const blockKey = "button-link:test";

      // The chrome only renders its keyed wrapper while the editor is active.
      // Enter the editor (rather than just flipping `isActive`) so the canvas
      // mounts the block and the draft layers are seeded; the block-reveal
      // service subscribes to the selection seam at boot and scrolls the
      // selected block into view through it.
      const wireframe = owner.lookup("service:wireframe-workspace");
      wireframe.siteSettings.wireframe_enabled = true;
      logIn(owner);
      wireframe.enter();

      await render(
        <template>
          <BlockChrome
            @blockName="button-link"
            @blockKey={{blockKey}}
            @outletName="test-outlet"
            @WrappedComponent={{WrappedBlock}}
          />
        </template>
      );

      const el = document.querySelector(`[data-wf-block-key="${blockKey}"]`);
      sinon.stub(el, "getBoundingClientRect").returns({
        top: rect.top,
        bottom: rect.top + rect.height,
        height: rect.height,
        left: 0,
        right: 0,
        width: 0,
        x: 0,
        y: rect.top,
      });
      const scrollSpy = sinon.stub(el, "scrollIntoView");

      return { blockKey, scrollSpy };
    }

    function select(owner, blockKey) {
      const wireframe = owner.lookup("service:wireframe-workspace");
      return wireframe.wireframeSelection.selectBlock({
        key: blockKey,
        name: "button-link",
        args: {},
        metadata: null,
        outletName: "test-outlet",
      });
    }

    test("centers an off-screen block that fits the viewport", async function (assert) {
      // Short block sitting below the fold.
      const { blockKey, scrollSpy } = await setupBlock(this.owner, {
        top: window.innerHeight + 200,
        height: 100,
      });

      select(this.owner, blockKey);
      await settled();

      assert.true(scrollSpy.calledOnce, "scrolls the block into view");
      assert.strictEqual(
        scrollSpy.firstCall.args[0].block,
        "center",
        "centers a block that fits the viewport"
      );
    });

    test("top-aligns a block taller than the viewport", async function (assert) {
      // Block taller than the viewport, starting above the fold.
      const { blockKey, scrollSpy } = await setupBlock(this.owner, {
        top: -100,
        height: window.innerHeight + 500,
      });

      select(this.owner, blockKey);
      await settled();

      assert.true(scrollSpy.calledOnce, "scrolls the block into view");
      assert.strictEqual(
        scrollSpy.firstCall.args[0].block,
        "start",
        "shows the top of a block that's taller than the viewport"
      );
    });

    test("does not scroll a block that's already fully visible", async function (assert) {
      const { blockKey, scrollSpy } = await setupBlock(this.owner, {
        top: 50,
        height: 100,
      });

      select(this.owner, blockKey);
      await settled();

      assert.true(
        scrollSpy.notCalled,
        "leaves an already-visible block in place"
      );
    });
  }
);
