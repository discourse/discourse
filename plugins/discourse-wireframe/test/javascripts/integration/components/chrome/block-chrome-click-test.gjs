import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import BlockChrome from "discourse/plugins/discourse-wireframe/discourse/components/editor/chrome/block-chrome";
import { queryOf } from "../../../helpers/wireframe-peers";

// A minimal stand-in for the wrapped block. The chrome derives a click's
// edit "kind" from the registered block metadata (keyed by `@blockName`),
// not from this component — so all it needs to emit is the same
// `data-block-arg` markup a real `button-link` renders: a native
// `<button>` for the `href` (URL) arg with the label nested inside it.
const WrappedButtonLink = <template>
  <button type="button" data-block-arg="href">
    <span data-block-arg="label">Label</span>
  </button>
</template>;

module(
  "Integration | discourse-wireframe | block-chrome click dispatch",
  function (hooks) {
    setupRenderingTest(hooks);

    test("ignores keyboard-synthesized clicks on a URL arg", async function (assert) {
      const wireframe = this.owner.lookup("service:wireframe-workspace");
      const linkEdit = this.owner.lookup("service:wireframe-inplace-link");
      const blockKey = "button-link:test";

      this.owner.lookup("service:wireframe-edit-mode").activate();
      // `LinkEditState.start` bails unless the block resolves to a real
      // layout entry, so stub the lookup — opening that session is exactly
      // the behavior we're asserting the guard suppresses.
      queryOf(wireframe).findEntryAndOutletSync = () => ({
        entry: { args: {} },
        outletName: "test-outlet",
      });
      // The URL branch only fires for an already-selected block.
      await wireframe.wireframeSelection.selectBlock({ key: blockKey });

      await render(
        <template>
          <BlockChrome
            @blockName="button-link"
            @blockKey={{blockKey}}
            @outletName="test-outlet"
            @WrappedComponent={{WrappedButtonLink}}
          />
        </template>
      );

      const hrefEl = document.querySelector("[data-block-arg='href']");

      // A native <button> activated via Space/Enter dispatches a click with
      // `detail === 0`. While the caret sits in the nested label editor,
      // typing a space activates the button and would otherwise pop the URL
      // editor open and steal focus.
      hrefEl.dispatchEvent(
        new MouseEvent("click", { bubbles: true, cancelable: true, detail: 0 })
      );
      await settled();

      assert.strictEqual(
        linkEdit.blockKey,
        null,
        "keyboard-synthesized click does not open a URL-edit session"
      );

      // A genuine pointer click (detail >= 1) must still open the editor.
      hrefEl.dispatchEvent(
        new MouseEvent("click", { bubbles: true, cancelable: true, detail: 1 })
      );
      await settled();

      assert.strictEqual(
        linkEdit.blockKey,
        blockKey,
        "pointer click opens the URL-edit session for the block"
      );
    });
  }
);
