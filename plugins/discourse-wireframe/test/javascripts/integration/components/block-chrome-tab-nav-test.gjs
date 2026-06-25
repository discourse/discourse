import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import BlockChrome from "discourse/plugins/discourse-wireframe/discourse/components/editor/block-chrome";

// A minimal stand-in for a wrapped tabs block: a body the chrome treats as a
// plain selection target, plus a tab button carrying the `data-wf-tab-panel-key`
// marker the tabs block adds to each tab in an editing context.
const WrappedTabs = <template>
  <div class="d-block-tabs">
    <button
      type="button"
      class="d-block-tabs__tab"
      data-wf-tab-panel-key="layout:panel-b"
    >Tab B</button>
    <span class="body">panel</span>
  </div>
</template>;

function clickEl(el, detail) {
  el.dispatchEvent(
    new MouseEvent("click", { bubbles: true, cancelable: true, detail })
  );
}

module(
  "Integration | discourse-wireframe | block-chrome tab nav",
  function (hooks) {
    setupRenderingTest(hooks);

    test("a synthesized (detail 0) tab click reveals without selecting; a real click selects", async function (assert) {
      const wireframe = this.owner.lookup("service:wireframe");
      wireframe.isActive = true;

      // `selectBlock` is an `@action` (a getter-only accessor), so record its
      // calls by redefining the configurable property rather than assigning.
      const selected = [];
      Object.defineProperty(wireframe, "selectBlock", {
        configurable: true,
        value: (data) => selected.push(data),
      });

      await render(
        <template>
          <BlockChrome
            @blockName="tabs"
            @blockKey="tabs:test"
            @outletName="test-outlet"
            @WrappedComponent={{WrappedTabs}}
          />
        </template>
      );

      // Ignore any selection that happened while mounting; isolate the clicks.
      selected.length = 0;

      // The drag-time reveal clicks the tab button programmatically; such a
      // synthesized click carries `detail === 0` and must NOT select the block
      // (the chrome bails before its tab-selection routing), so paging a panel
      // into view mid-drag never changes selection.
      clickEl(document.querySelector("[data-wf-tab-panel-key]"), 0);
      await settled();
      assert.strictEqual(
        selected.length,
        0,
        "a synthesized tab click does not select the block"
      );

      // A real pointer click on a tab (detail 1) still routes selection to that
      // tab's panel — the shipped functional tab-paging behaviour.
      clickEl(document.querySelector("[data-wf-tab-panel-key]"), 1);
      await settled();
      assert.deepEqual(
        selected,
        [{ key: "layout:panel-b" }],
        "a real tab click selects that tab's panel"
      );
    });
  }
);
