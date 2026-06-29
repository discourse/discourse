import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import BlockChrome from "discourse/plugins/discourse-wireframe/discourse/components/editor/block-chrome";

// A minimal stand-in for a wrapped carousel: a body the chrome treats as a
// plain selection target, plus a nav control carrying the `data-wf-carousel-nav`
// marker the carousel adds to its prev/next/dot buttons in an editing context.
const WrappedCarousel = <template>
  <div class="d-block-carousel">
    <span class="body">slide</span>
    <button type="button" class="nav" data-wf-carousel-nav="true">›</button>
  </div>
</template>;

function clickEl(el) {
  el.dispatchEvent(
    new MouseEvent("click", { bubbles: true, cancelable: true, detail: 1 })
  );
}

module(
  "Integration | discourse-wireframe | block-chrome carousel nav",
  function (hooks) {
    setupRenderingTest(hooks);

    test("a nav-control click pages without selecting the block", async function (assert) {
      const wireframe = this.owner.lookup("service:wireframe");
      this.owner.lookup("service:wireframe-session").activate();

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
            @blockName="carousel"
            @blockKey="carousel:test"
            @outletName="test-outlet"
            @WrappedComponent={{WrappedCarousel}}
          />
        </template>
      );

      // Ignore any selection that happened while mounting; isolate the clicks.
      selected.length = 0;

      // The carousel's own handler does the paging during bubbling; the chrome
      // must let the click through without re-selecting the block.
      clickEl(document.querySelector("[data-wf-carousel-nav]"));
      await settled();
      assert.strictEqual(
        selected.length,
        0,
        "paging a slide into view does not select the block"
      );

      // Control: a click elsewhere on the chrome still selects the block, so
      // the exemption is specific to the nav controls.
      clickEl(document.querySelector(".body"));
      await settled();
      assert.strictEqual(selected.length, 1, "clicking the body selects");
      assert.strictEqual(
        selected[0].key,
        "carousel:test",
        "the selected block is the chrome's own block"
      );
    });
  }
);
