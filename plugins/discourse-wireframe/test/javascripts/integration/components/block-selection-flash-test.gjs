import { render, rerender, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import BlockChrome from "discourse/plugins/discourse-wireframe/discourse/components/editor/block-chrome";

// `flash` briefly toggles the `--just-selected` class on a block's rendered
// element to draw the eye to it. It's invoked explicitly from the outline /
// insert paths — NOT from `selectBlock` — so a plain canvas-click selection
// stays quiet.
const WrappedBlock = <template>
  <div data-block-arg="label">Block</div>
</template>;

module(
  "Integration | discourse-wireframe | block selection flash",
  function (hooks) {
    setupRenderingTest(hooks);

    const BLOCK_KEY = "button-link:test";

    // Renders a block chrome (active editor) and returns spies on the keyed
    // element's classList so we can observe the transient flash class even
    // after its timed removal.
    async function setupBlock(owner) {
      // The chrome only renders its keyed wrapper while the editor is active.
      owner.lookup("service:wireframe-session").activate();

      await render(
        <template>
          <BlockChrome
            @blockName="button-link"
            @blockKey={{BLOCK_KEY}}
            @outletName="test-outlet"
            @WrappedComponent={{WrappedBlock}}
          />
        </template>
      );

      const el = document.querySelector(`[data-wf-block-key="${BLOCK_KEY}"]`);
      return {
        addSpy: sinon.spy(el.classList, "add"),
        removeSpy: sinon.spy(el.classList, "remove"),
      };
    }

    test("flashing a block toggles the just-selected class on and off", async function (assert) {
      const { addSpy, removeSpy } = await setupBlock(this.owner);

      this.owner.lookup("service:wireframe-block-reveal").flash(BLOCK_KEY);
      await settled();

      assert.true(
        addSpy.calledWith("--just-selected"),
        "applies the flash class"
      );
      // `discourseLater` is flushed by `settled`, so the timed removal has run.
      assert.true(
        removeSpy.calledWith("--just-selected"),
        "removes the flash class once the flash is done"
      );
    });

    test("the flash survives the selection-driven class re-render", async function (assert) {
      await setupBlock(this.owner);
      const selection = this.owner.lookup("service:wireframe-selection");
      const blockReveal = this.owner.lookup("service:wireframe-block-reveal");

      // The outline's `selectRow` selects the block (which toggles the
      // `--selected` class on the chrome, scheduling a re-render of its class
      // binding) and then immediately flashes it. The render that follows must
      // not wipe the just-added flash class.
      selection.selectBlock({
        key: BLOCK_KEY,
        name: "button-link",
        args: {},
        metadata: null,
        outletName: "test-outlet",
      });
      blockReveal.flash(BLOCK_KEY);

      // `rerender` flushes the pending render (and `afterRender`) without
      // advancing the timer that later clears the flash, so the class we
      // observe is the one a user would actually see animate.
      await rerender();

      const el = document.querySelector(`[data-wf-block-key="${BLOCK_KEY}"]`);
      assert.true(
        el.classList.contains("--just-selected"),
        "the flash class is still present after the selection re-render"
      );
    });

    test("plain selection does not flash the block", async function (assert) {
      const { addSpy } = await setupBlock(this.owner);

      // A bare `selectBlock` is the canvas-click path; it must not flash.
      this.owner.lookup("service:wireframe-selection").selectBlock({
        key: BLOCK_KEY,
        name: "button-link",
        args: {},
        metadata: null,
        outletName: "test-outlet",
      });
      await settled();

      assert.false(
        addSpy.calledWith("--just-selected"),
        "selecting without flashing leaves the block unflashed"
      );
    });
  }
);
