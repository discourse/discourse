import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import BlockChrome from "discourse/plugins/discourse-wireframe/discourse/components/editor/block-chrome";

// `flashBlock` briefly toggles the `--just-selected` class on a block's
// rendered element to draw the eye to it. It's invoked explicitly from the
// outline / insert paths — NOT from `selectBlock` — so a plain canvas-click
// selection stays quiet.
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
      owner.lookup("service:wireframe").isActive = true;

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

      this.owner.lookup("service:wireframe").flashBlock(BLOCK_KEY);
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

    test("plain selection does not flash the block", async function (assert) {
      const { addSpy } = await setupBlock(this.owner);

      // A bare `selectBlock` is the canvas-click path; it must not flash.
      this.owner.lookup("service:wireframe").selectBlock({
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
