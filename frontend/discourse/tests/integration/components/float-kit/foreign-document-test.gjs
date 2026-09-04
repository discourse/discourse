import {
  click,
  render,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import DMenu from "discourse/float-kit/components/d-menu";
import DMenus from "discourse/float-kit/components/d-menus";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import DTooltips from "discourse/float-kit/components/d-tooltips";
import { getScrollParent } from "discourse/float-kit/lib/get-scroll-parent";
import { adjacentTabStop } from "discourse/float-kit/lib/tab-order";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DConditionalInElement from "discourse/ui-kit/d-conditional-in-element";
import { writeSkeleton } from "discourse/ui-kit/panel-dock/-internals/window-skeleton";

/**
 * Oracle for float-kit rendering into a document that is not the one the
 * application booted in. A panel moved into its own browser window renders
 * there across documents, so anything that resolves an outlet, a listener
 * target or a scroll parent from the global document lands in the wrong place
 * and, worse, lands somewhere nobody is looking.
 */
module(
  "Integration | Component | float-kit foreign document",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.frames = [];
    });

    hooks.afterEach(function () {
      this.frames.forEach((frame) => frame.remove());
    });

    /**
     * A blank document in another realm, with none of a panel window's shell.
     *
     * The shell deliberately hides its document until the stylesheets it clones
     * have settled, which would make every element in it unfocusable — real
     * behaviour, but not what these cases are about.
     */
    function bareDocument(context) {
      const frame = document.createElement("iframe");
      frame.setAttribute("aria-hidden", "true");
      frame.style.width = "600px";
      frame.style.height = "400px";
      document.body.appendChild(frame);
      context.frames.push(frame);
      return frame.contentDocument;
    }

    /** A prepared document standing in for a panel's own window. */
    function foreignDocument(context) {
      const frame = document.createElement("iframe");
      frame.setAttribute("aria-hidden", "true");
      frame.style.width = "600px";
      frame.style.height = "400px";
      document.body.appendChild(frame);
      context.frames.push(frame);

      const doc = frame.contentDocument;
      const skeleton = writeSkeleton(doc, "float-kit-oracle", "Oracle");
      context.frames.push({ remove: () => skeleton.dispose() });
      return { doc, mount: skeleton.mount };
    }

    test("foreign document menu content renders into that document's outlet", async function (assert) {
      const { doc, mount } = foreignDocument(this);

      await render(
        <template>
          {{! The application's own outlet, so a menu that resolves the wrong
              document has somewhere plausible to land. }}
          <DMenus />

          <DConditionalInElement @element={{mount}}>
            <DMenu @label="Open" @identifier="foreign-oracle" @inline={{false}}>
              <:content><span
                  class="foreign-menu-content"
                >Inside</span></:content>
            </DMenu>
          </DConditionalInElement>
        </template>
      );

      await click(mount.querySelector(".fk-d-menu__trigger"));

      assert
        .dom("#d-menu-portals .foreign-menu-content", doc)
        .exists("the menu renders in the document its trigger lives in");
      assert
        .dom(".foreign-menu-content")
        .doesNotExist("and not in the document the application booted in");
    });

    test("foreign document tooltip content renders into that document's outlet", async function (assert) {
      const { doc, mount } = foreignDocument(this);

      await render(
        <template>
          <DTooltips />

          <DConditionalInElement @element={{mount}}>
            <DTooltip @identifier="foreign-tooltip-oracle" @inline={{false}}>
              <:trigger>Hover</:trigger>
              <:content><span
                  class="foreign-tip-content"
                >Inside</span></:content>
            </DTooltip>
          </DConditionalInElement>
        </template>
      );

      await click(mount.querySelector(".fk-d-tooltip__trigger"));

      assert
        .dom("#d-tooltip-portals .foreign-tip-content", doc)
        .exists("the tooltip renders in its trigger's document");
      assert
        .dom(".foreign-tip-content")
        .doesNotExist("and not in the application's document");
    });

    test("foreign document escape closes a menu opened there", async function (assert) {
      const { doc, mount } = foreignDocument(this);

      await render(
        <template>
          <DMenus />

          <DConditionalInElement @element={{mount}}>
            <DMenu @label="Open" @identifier="foreign-escape-oracle">
              <:content><span
                  class="foreign-menu-content"
                >Inside</span></:content>
            </DMenu>
          </DConditionalInElement>
        </template>
      );

      const trigger = mount.querySelector(".fk-d-menu__trigger");
      await click(trigger);
      assert.dom(trigger).hasAttribute("aria-expanded", "true");

      await triggerKeyEvent(doc.documentElement, "keydown", "Escape");

      assert
        .dom(trigger)
        .hasAttribute(
          "aria-expanded",
          "false",
          "a keystroke in the panel's window never reaches the page's listener"
        );
    });

    test("foreign document outside click closes a menu opened there", async function (assert) {
      const { mount } = foreignDocument(this);

      await render(
        <template>
          <DMenus />

          <DConditionalInElement @element={{mount}}>
            <div class="foreign-outside">Elsewhere</div>
            <DMenu @label="Open" @identifier="foreign-outside-oracle">
              <:content><span
                  class="foreign-menu-content"
                >Inside</span></:content>
            </DMenu>
          </DConditionalInElement>
        </template>
      );

      const trigger = mount.querySelector(".fk-d-menu__trigger");
      await click(trigger);
      assert.dom(trigger).hasAttribute("aria-expanded", "true");

      // A pointer press, not a click: `click()` fires mousedown/mouseup/click and
      // never a pointer event, which is not what dismissal listens for.
      await triggerEvent(
        mount.querySelector(".foreign-outside"),
        "pointerdown"
      );

      assert
        .dom(trigger)
        .hasAttribute(
          "aria-expanded",
          "false",
          "a pointer press in that document dismisses it"
        );
    });

    test("foreign document leaves the application's own menus alone", async function (assert) {
      await render(
        <template>
          <DMenus />

          <DMenu
            @label="Open"
            @identifier="main-document-oracle"
            @inline={{false}}
          >
            <:content><span class="main-menu-content">Inside</span></:content>
          </DMenu>
        </template>
      );

      await click(".fk-d-menu__trigger");

      assert
        .dom("#d-menu-portals .main-menu-content")
        .exists("a menu in the application's document is untouched");
    });

    test("foreign document scroll parent stops at that document's root", async function (assert) {
      const doc = bareDocument(this);
      const inner = doc.createElement("div");
      doc.body.appendChild(inner);

      assert.strictEqual(
        getScrollParent(doc.documentElement),
        null,
        "the foreign root is a root, not something to keep walking past"
      );
      assert.notStrictEqual(
        getScrollParent(inner),
        undefined,
        "an element inside it resolves without reaching the page's root"
      );
    });

    test("foreign document tab stops default to the anchor's own document", async function (assert) {
      const doc = bareDocument(this);

      const first = doc.createElement("button");
      first.textContent = "First";
      const second = doc.createElement("button");
      second.textContent = "Second";
      doc.body.append(first, second);

      assert.strictEqual(
        adjacentTabStop(first, { forward: true }),
        second,
        "the search defaults to the document the anchor is in"
      );
    });
  }
);
