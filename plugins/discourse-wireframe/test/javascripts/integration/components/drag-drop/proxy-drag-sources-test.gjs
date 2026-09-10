import { find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  centerOf,
  dragEvent,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";
import proxyDragSources from "discourse/plugins/discourse-wireframe/discourse/modifiers/proxy-drag-sources";

module(
  "Integration | discourse-wireframe | proxy drag sources",
  function (hooks) {
    setupRenderingTest(hooks);

    test("DTabs adoption follows proxies mounted after the initial render without a version change", async function (assert) {
      this.set("showProxy", false);
      await render(
        <template>
          <div
            class="wireframe-block-chrome"
            {{proxyDragSources outletName="hero" version=1}}
          >
            {{#if this.showProxy}}
              <button
                data-wf-drop-child-key="layout:late"
                id="late-proxy"
                type="button"
              >Late tab</button>
            {{/if}}
          </div>
        </template>
      );
      this.set("showProxy", true);
      await settled();
      const proxy = find("#late-proxy");
      const dataTransfer = new DataTransfer();
      await dragEvent("#late-proxy", "dragstart", {
        dataTransfer,
        ...centerOf("#late-proxy"),
      });
      assert.strictEqual(
        this.owner.lookup("service:wireframe-drag-session").sourceKey,
        "layout:late",
        "a deferred proxy becomes draggable without a structural edit"
      );
      await dragEvent("#late-proxy", "dragend", {
        dataTransfer,
        ...centerOf("#late-proxy"),
      });
      this.set("showProxy", false);
      await settled();
      assert
        .dom(proxy)
        .doesNotHaveAttribute(
          "data-drag-source",
          "a removed proxy releases its source registration"
        );
    });

    test("makes each proxy child a wf-block drag source for its own block", async function (assert) {
      const drags = [];
      const dragSession = this.owner.lookup("service:wireframe-drag-session");
      // `startDrag` / `endDrag` are `@action`s (getter-only accessors), so spy
      // by redefining the configurable property rather than assigning.
      Object.defineProperty(dragSession, "startDrag", {
        configurable: true,
        value: (data) => drags.push(data),
      });
      Object.defineProperty(dragSession, "endDrag", {
        configurable: true,
        value: () => {},
      });

      // A stand-in container chrome whose two children are key-carrying proxies
      // (a tab strip's buttons), with no chrome of their own.
      await render(
        <template>
          <div
            class="wireframe-block-chrome"
            {{proxyDragSources outletName="hero" version=1}}
          >
            <button data-wf-drop-child-key="layout:p1" id="p1" type="button">Tab
              1</button>
            <button data-wf-drop-child-key="layout:p2" id="p2" type="button">Tab
              2</button>
          </div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      await dragEvent("#p2", "dragstart", { dataTransfer, ...centerOf("#p2") });

      assert.deepEqual(
        drags.at(-1),
        { type: "wf-block", blockKey: "layout:p2", outletName: "hero" },
        "dragging a proxy starts a wf-block drag carrying its child's key"
      );

      await dragEvent("#p2", "dragend", { dataTransfer, ...centerOf("#p2") });
    });
  }
);
