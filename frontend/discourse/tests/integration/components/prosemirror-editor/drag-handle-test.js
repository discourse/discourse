import Service from "@ember/service";
import {
  clearRender,
  click,
  find,
  findAll,
  settled,
  triggerEvent,
  triggerKeyEvent,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { NodeSelection, TextSelection } from "prosemirror-state";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  nodeActionsFor,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { setupRichEditor } from "discourse/tests/helpers/rich-editor-helper";
import { stubPointerCapture } from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";

const DOC = "First paragraph.\n\nSecond paragraph.\n\nThird paragraph.";
const NESTED_DOC =
  "* Parent\n  * First nested\n  * Second nested\n\nLast paragraph.";
const NESTED_LEVEL_DOC = "* Parent\n  * Nested\n* Sibling";

function handle() {
  return find(".composer-drag-handle");
}

async function hoverElement(view, element) {
  const rect = element.getBoundingClientRect();

  view.dom.dispatchEvent(
    new PointerEvent("pointermove", {
      bubbles: true,
      clientX: rect.left + 20,
      clientY: rect.top + 6,
    })
  );
  await settled();

  return element;
}

/** Puts the pointer over a block, which is what reveals its handle. */
async function hoverBlock(view, index) {
  const block = view.dom.children[index];

  return hoverElement(view, block);
}

/** The first top-level block, as the handle would resolve it. */
function firstBlock(view) {
  const pos = 0;
  return { node: view.state.doc.nodeAt(pos), pos, view, pluginParams: {} };
}

function classNames(items) {
  return items.map((item) => (item.divider ? "---" : item.className));
}

module(
  "Integration | Component | prosemirror-editor - drag handle",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.afterEach(() => resetRichEditorExtensions());

    test("a handle appears for the block under the pointer", async function (assert) {
      const [editor] = await setupRichEditor(assert, DOC);
      const { view } = editor;

      assert
        .dom(".composer-drag-handle")
        .exists("one handle serves every block");
      assert
        .dom(".composer-drag-handle")
        .doesNotHaveClass("--visible", "and stays out of the way until wanted");

      await hoverBlock(view, 0);
      assert.dom(".composer-drag-handle").hasClass("--visible");
      assert.strictEqual(
        parseFloat(handle().style.left),
        view.dom.getBoundingClientRect().left -
          parseFloat(getComputedStyle(document.documentElement).fontSize) / 2,
        "the handle floats half a rem across the editor edge"
      );

      // The placement is read off the inline style rather than the rendered
      // rect: a rendering test loads no stylesheet, so the handle is never
      // actually positioned.
      const first = handle().style.top;
      await hoverBlock(view, 2);

      assert.notStrictEqual(
        handle().style.top,
        first,
        "and follows the pointer from block to block"
      );
    });

    test("a handle stays inside the visible editor viewport", async function (assert) {
      const [editor] = await setupRichEditor(assert, DOC);
      const { view } = editor;
      const block = view.dom.children[0];
      const scrollport = view.dom.parentElement;
      const blockBounds = sinon.stub(block, "getBoundingClientRect");
      sinon.stub(handle(), "offsetHeight").get(() => 24);
      sinon.stub(view, "posAtCoords").returns({ pos: 1 });
      sinon.stub(scrollport, "clientHeight").get(() => 100);
      sinon.stub(scrollport, "clientTop").get(() => 0);
      sinon.stub(scrollport, "getBoundingClientRect").returns({
        top: 0,
        right: 200,
        bottom: 100,
        left: 0,
        width: 200,
        height: 100,
      });

      blockBounds.returns({
        top: -1,
        right: 200,
        bottom: 23,
        left: 0,
        width: 200,
        height: 24,
      });
      await hoverElement(view, block);

      assert
        .dom(".composer-drag-handle")
        .doesNotHaveClass("--visible", "a handle above the viewport is hidden")
        .hasAttribute("tabindex", "-1", "it cannot receive keyboard focus")
        .hasAria(
          "hidden",
          "true",
          "it is also hidden from assistive technology"
        );

      blockBounds.returns({
        top: 80,
        right: 200,
        bottom: 104,
        left: 0,
        width: 200,
        height: 24,
      });
      await hoverElement(view, block);

      assert
        .dom(".composer-drag-handle")
        .doesNotHaveClass("--visible", "a handle below the viewport is hidden")
        .hasAttribute("tabindex", "-1", "it remains outside the tab order")
        .hasAria(
          "hidden",
          "true",
          "it remains hidden from assistive technology"
        );
    });

    test("nested list items have their own drag target", async function (assert) {
      const [editor] = await setupRichEditor(assert, NESTED_DOC);
      const { view } = editor;
      const nestedItems = findAll(".ProseMirror > ul > li > ul > li");
      sinon.stub(handle(), "offsetWidth").get(() => 20);

      assert.strictEqual(
        nestedItems.length,
        2,
        "the fixture contains two nested siblings"
      );

      await hoverElement(view, nestedItems[1]);

      const nestedBounds = nestedItems[1].getBoundingClientRect();
      const listStyle = getComputedStyle(nestedItems[1].parentElement);
      const markerInset =
        parseFloat(listStyle.paddingLeft) ||
        parseFloat(listStyle.fontSize) * 1.25;
      const offset =
        parseFloat(getComputedStyle(document.documentElement).fontSize) / 2;
      assert.strictEqual(
        parseFloat(handle().style.left) + handle().offsetWidth,
        nestedBounds.left - markerInset - offset,
        "the handle sits before the nested marker instead of over its text"
      );

      stubPointerCapture(handle());
      const firstBounds = nestedItems[0].getBoundingClientRect();
      const from = {
        button: 0,
        pointerId: 1,
        clientX: 20,
        clientY: 80,
      };
      const to = {
        pointerId: 1,
        clientX: firstBounds.left + 5,
        clientY: firstBounds.top + 1,
      };
      await triggerEvent(handle(), "pointerdown", from);
      await triggerEvent(handle(), "pointermove", to);

      assert.strictEqual(
        view.state.selection.node.textContent,
        "Second nested",
        "the nested list item itself is selected"
      );
      assert.strictEqual(
        parseFloat(find(".composer-drag-handle__drop-indicator").style.left),
        firstBounds.left,
        "the insertion marker stays at the nested level"
      );

      await triggerEvent(handle(), "pointerup", to);

      assert.true(
        editor.value.indexOf("* Second nested") <
          editor.value.indexOf("* First nested"),
        "the nested siblings are reordered without flattening the list"
      );
    });

    test("a whole list uses its first item's marker rail", async function (assert) {
      const [editor] = await setupRichEditor(assert, NESTED_DOC);
      const { view } = editor;
      const list = view.dom.children[0];
      const firstItem = list.querySelector(":scope > li");
      sinon.stub(handle(), "offsetWidth").get(() => 20);
      sinon.stub(view, "posAtCoords").returns({ pos: 1 });

      await hoverElement(view, list);

      const itemBounds = firstItem.getBoundingClientRect();
      const listStyle = getComputedStyle(list);
      const markerInset =
        parseFloat(listStyle.paddingLeft) ||
        parseFloat(listStyle.fontSize) * 1.25;
      const offset =
        parseFloat(getComputedStyle(document.documentElement).fontSize) / 2;
      const handleLeft = parseFloat(handle().style.left);

      assert.strictEqual(
        handleLeft + handle().offsetWidth,
        itemBounds.left - markerInset - offset,
        "the whole-list handle is beside its first marker"
      );
    });

    test("crossing a list marker keeps the first item targeted", async function (assert) {
      const [editor] = await setupRichEditor(assert, NESTED_DOC);
      const { view } = editor;
      const firstItem = find(".ProseMirror > ul > li");
      let firstItemPos;

      view.state.doc.descendants((node, pos) => {
        if (firstItemPos === undefined && node.type.name === "list_item") {
          firstItemPos = pos;
        }
      });

      sinon.stub(handle(), "offsetWidth").get(() => 20);
      sinon.stub(handle(), "offsetHeight").get(() => 24);
      sinon
        .stub(view, "posAtCoords")
        .onFirstCall()
        .returns({ pos: firstItemPos + 2 })
        .onSecondCall()
        .returns({ pos: 1 });

      await hoverElement(view, firstItem);

      const itemBounds = firstItem.getBoundingClientRect();
      const handleLeft = parseFloat(handle().style.left);
      const handleTop = parseFloat(handle().style.top);
      view.dom.dispatchEvent(
        new PointerEvent("pointermove", {
          bubbles: true,
          clientX: (handleLeft + handle().offsetWidth + itemBounds.left) / 2,
          clientY: itemBounds.top + 6,
        })
      );
      await settled();

      stubPointerCapture(handle());
      await triggerEvent(handle(), "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: handleLeft + 10,
        clientY: handleTop + 6,
      });
      await triggerEvent(handle(), "pointermove", {
        pointerId: 1,
        clientX: handleLeft + 16,
        clientY: handleTop + 12,
      });

      assert.strictEqual(
        view.state.selection.node.type.name,
        "list_item",
        "reaching for the grip does not replace the item with its parent list"
      );

      await triggerEvent(handle(), "pointercancel", {
        pointerId: 1,
        clientX: handleLeft + 16,
        clientY: handleTop + 12,
      });
    });

    test("a nested item can be moved to a compatible list level", async function (assert) {
      const [editor] = await setupRichEditor(assert, NESTED_LEVEL_DOC);
      const { view } = editor;
      const nested = find(".ProseMirror > ul > li > ul > li");
      const sibling = findAll(".ProseMirror > ul > li")[1];

      await hoverElement(view, nested);
      stubPointerCapture(handle());

      const targetBounds = sibling.getBoundingClientRect();
      const from = {
        button: 0,
        pointerId: 1,
        clientX: 20,
        clientY: 80,
      };
      const to = {
        pointerId: 1,
        clientX: targetBounds.left + 5,
        clientY: targetBounds.top + 1,
      };
      await triggerEvent(handle(), "pointerdown", from);
      await triggerEvent(handle(), "pointermove", to);
      await triggerEvent(handle(), "pointerup", to);

      assert
        .dom(".ProseMirror > ul > li")
        .exists({ count: 3 }, "the item is inserted at the outer list level");
      assert
        .dom(".ProseMirror li > ul > li")
        .doesNotExist("the emptied nested list is removed");
      assert.strictEqual(
        editor.value,
        "* Parent\n* Nested\n* Sibling",
        "the item keeps its list-item content while changing levels"
      );
    });

    test("a list item can be moved into a compatible nested list", async function (assert) {
      const [editor] = await setupRichEditor(assert, NESTED_LEVEL_DOC);
      const { view } = editor;
      const nested = find(".ProseMirror > ul > li > ul > li");
      const sibling = findAll(".ProseMirror > ul > li")[1];

      await hoverElement(view, sibling);
      stubPointerCapture(handle());

      const targetBounds = nested.getBoundingClientRect();
      const from = {
        button: 0,
        pointerId: 1,
        clientX: 20,
        clientY: 80,
      };
      const to = {
        pointerId: 1,
        clientX: targetBounds.left + 5,
        clientY: targetBounds.bottom - 1,
      };
      await triggerEvent(handle(), "pointerdown", from);
      await triggerEvent(handle(), "pointermove", to);
      await triggerEvent(handle(), "pointerup", to);

      assert
        .dom(".ProseMirror > ul > li")
        .exists({ count: 1 }, "the item leaves the outer list level");
      assert
        .dom(".ProseMirror > ul > li > ul > li")
        .exists({ count: 2 }, "the item joins the nested list");
      assert.strictEqual(
        editor.value,
        "* Parent\n  * Nested\n  * Sibling",
        "the item keeps its content while becoming nested"
      );
    });

    test("a list item cannot be dropped into its own descendants", async function (assert) {
      const [editor] = await setupRichEditor(assert, NESTED_LEVEL_DOC);
      const { view } = editor;
      const parent = find(".ProseMirror > ul > li");
      const nested = find(".ProseMirror > ul > li > ul > li");

      await hoverElement(view, parent);
      stubPointerCapture(handle());

      const targetBounds = nested.getBoundingClientRect();
      const from = {
        button: 0,
        pointerId: 1,
        clientX: 20,
        clientY: 20,
      };
      const to = {
        pointerId: 1,
        clientX: targetBounds.left + 5,
        clientY: targetBounds.top + 1,
      };
      await triggerEvent(handle(), "pointerdown", from);
      await triggerEvent(handle(), "pointermove", to);

      assert
        .dom(".composer-drag-handle__drop-indicator")
        .doesNotHaveClass(
          "--visible",
          "an impossible recursive destination is not offered"
        );

      await triggerEvent(handle(), "pointerup", to);

      assert.strictEqual(
        editor.value,
        NESTED_LEVEL_DOC,
        "the document remains unchanged"
      );
    });

    test("pressing and releasing the handle does not move the block", async function (assert) {
      const [editor] = await setupRichEditor(assert, DOC);

      await hoverBlock(editor.view, 0);
      stubPointerCapture(handle());
      await triggerEvent(handle(), "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 20,
        clientY: 20,
      });
      await triggerEvent(handle(), "pointerup", {
        pointerId: 1,
        clientX: 20,
        clientY: 20,
      });

      assert.strictEqual(editor.value, DOC, "a click is not treated as a drag");
    });

    test("an inactive handle is hidden from assistive technology", async function (assert) {
      await setupRichEditor(assert, DOC);

      assert.dom(".composer-drag-handle").hasAria("label");
      assert.dom(".composer-drag-handle").doesNotHaveAttribute("hidden");
      assert
        .dom(".composer-drag-handle")
        .hasAttribute(
          "aria-hidden",
          "true",
          "it is not an action without a target"
        );
    });

    test("the desktop handle does not follow the caret", async function (assert) {
      const [editor] = await setupRichEditor(assert, DOC);

      editor.view.focus();
      await settled();

      assert
        .dom(".composer-drag-handle")
        .doesNotHaveClass(
          "--visible",
          "focusing a block does not reveal its handle"
        );
      assert
        .dom(".composer-drag-handle")
        .hasAttribute("tabindex", "-1", "the hidden handle is not a tab stop");
      assert
        .dom(".ProseMirror")
        .hasAttribute(
          "aria-keyshortcuts",
          "Alt+Enter Shift+F10",
          "the focused editor advertises its action-menu shortcuts"
        );
    });

    test("a touch-first editor keeps the current block's handle available", async function (assert) {
      sinon
        .stub(this.owner.lookup("service:capabilities"), "touchFirst")
        .get(() => true);

      const [editor] = await setupRichEditor(assert, DOC);
      editor.view.focus();
      await settled();

      assert
        .dom(".composer-drag-handle")
        .hasClass("--touch", "the handle uses its in-editor touch placement");
      assert
        .dom(".composer-drag-handle")
        .hasClass(
          "--visible",
          "tapping into a block reveals its action handle"
        );
      assert
        .dom(".composer-drag-handle")
        .hasAttribute("tabindex", "0", "the touch handle remains actionable");
    });

    test("a touch handle mirrors its placement in RTL", async function (assert) {
      sinon
        .stub(this.owner.lookup("service:capabilities"), "touchFirst")
        .get(() => true);

      const [editor] = await setupRichEditor(assert, DOC);
      const { view } = editor;
      const block = view.dom.children[0];
      view.dom.style.direction = "rtl";
      sinon.stub(handle(), "offsetWidth").get(() => 20);

      await hoverBlock(view, 0);

      assert.strictEqual(
        parseFloat(handle().style.left),
        Math.max(
          block.getBoundingClientRect().left,
          view.dom.getBoundingClientRect().left
        ) + 6,
        "the touch handle uses the physical left edge away from RTL text"
      );
    });

    test("clicking the handle opens its node actions", async function (assert) {
      const [editor] = await setupRichEditor(assert, DOC, { withMenus: true });

      await hoverBlock(editor.view, 0);
      await click(".composer-drag-handle");
      await waitFor('.fk-d-menu[data-identifier="composer-node-menu"]');

      assert
        .dom(".composer-node-menu__duplicate")
        .exists("the duplicate action is rendered");
      assert
        .dom(".composer-node-menu__delete")
        .exists("the delete action is rendered");
      assert
        .dom(".composer-drag-handle")
        .hasAttribute(
          "aria-expanded",
          "true",
          "the disclosure state is exposed"
        );
      assert
        .dom('.fk-d-menu[data-identifier="composer-node-menu"]')
        .hasAttribute("role", "none", "the button list has no dialog wrapper");
    });

    test("Alt+Enter opens the current block's node actions", async function (assert) {
      const [editor] = await setupRichEditor(assert, DOC, { withMenus: true });

      editor.view.focus();
      await settled();
      await triggerKeyEvent(editor.view.dom, "keydown", "Enter", {
        altKey: true,
      });
      await waitFor('.fk-d-menu[data-identifier="composer-node-menu"]');

      assert
        .dom(".composer-node-menu__duplicate")
        .exists("the focused block's menu opens without a pointer");
    });

    test("Alt+Enter targets the current nested list item", async function (assert) {
      const [editor] = await setupRichEditor(assert, NESTED_DOC, {
        withMenus: true,
      });
      const { view } = editor;
      let nestedPos;

      view.state.doc.descendants((node, pos) => {
        if (
          node.type.name === "list_item" &&
          node.textContent === "Second nested"
        ) {
          nestedPos = pos;
        }
      });
      view.dispatch(
        view.state.tr.setSelection(
          TextSelection.create(view.state.doc, nestedPos + 2)
        )
      );
      view.focus();
      await settled();
      await triggerKeyEvent(view.dom, "keydown", "Enter", { altKey: true });
      await waitFor('.fk-d-menu[data-identifier="composer-node-menu"]');

      assert
        .dom(".composer-node-menu__move-up")
        .exists("the nested item's previous-sibling action is available");
      assert
        .dom(".composer-node-menu__move-down")
        .doesNotExist("the outer list's next-root-block action is not used");
      assert.strictEqual(
        view.state.selection.node.textContent,
        "Second nested",
        "the nested list item becomes the node selection"
      );
    });

    test("Alt+Enter targets a top-level NodeSelection", async function (assert) {
      const [editor] = await setupRichEditor(assert, DOC, { withMenus: true });
      const { view } = editor;
      view.dispatch(
        view.state.tr.setSelection(NodeSelection.create(view.state.doc, 0))
      );
      await settled();

      await triggerKeyEvent(view.dom, "keydown", "Enter", { altKey: true });
      await waitFor('.fk-d-menu[data-identifier="composer-node-menu"]');

      assert
        .dom(".composer-node-menu__duplicate")
        .exists("the selected top-level block's menu opens");
      assert.strictEqual(view.state.selection.from, 0);
    });

    test("a menu that resolves after teardown is destroyed", async function (assert) {
      let resolveMenu;
      let showCalls = 0;
      const lateMenu = { destroy: sinon.spy(), expanded: true };
      this.owner.register(
        "service:menu",
        class DeferredMenuService extends Service {
          close() {}

          show() {
            showCalls++;
            return new Promise((resolve) => {
              resolveMenu = resolve;
            });
          }
        }
      );
      const [editor] = await setupRichEditor(assert, DOC);

      await hoverBlock(editor.view, 0);
      handle().click();
      await waitUntil(() => showCalls === 1);
      await clearRender();

      resolveMenu(lateMenu);
      await settled();

      assert.true(
        lateMenu.destroy.calledOnce,
        "a late FloatKit instance cannot outlive the editor"
      );
    });

    test("plugins can register node actions that appear and run", async function (assert) {
      let runs = 0;

      withPluginApi((api) => {
        api.registerRichEditorExtension({
          nodeActions: {
            paragraph: () => [
              {
                label: "Test plugin action",
                className: "composer-node-menu__test-plugin-action",
                action: () => runs++,
              },
            ],
          },
        });
      });

      const [editor] = await setupRichEditor(assert, DOC, { withMenus: true });
      await hoverBlock(editor.view, 0);
      await click(".composer-drag-handle");
      await waitFor(".composer-node-menu__test-plugin-action");
      await click(".composer-node-menu__test-plugin-action");

      assert.strictEqual(runs, 1, "the plugin action runs from the real menu");
    });

    test("a disabled editor exposes no actionable handle", async function (assert) {
      const [editor] = await setupRichEditor(assert, DOC, {
        disabled: true,
        withMenus: true,
      });

      assert.false(editor.view.editable);
      assert
        .dom(".composer-drag-handle")
        .doesNotHaveClass(
          "--visible",
          "read-only content has no handle chrome"
        );
      assert.dom(".composer-drag-handle").hasAttribute("tabindex", "-1");

      handle().dispatchEvent(new MouseEvent("click", { bubbles: true }));
      nodeActionsFor("paragraph", firstBlock(editor.view))
        .find((item) => item.className === "composer-node-menu__duplicate")
        .action();
      await settled();

      assert
        .dom('.fk-d-menu[data-identifier="composer-node-menu"]')
        .doesNotExist("a synthetic click cannot open actions");
      assert.strictEqual(editor.value, DOC);
    });

    test("dragging stays in the block rail and marks the insertion point", async function (assert) {
      const [editor] = await setupRichEditor(assert, DOC);
      const { view } = editor;

      await hoverBlock(view, 0);
      stubPointerCapture(handle());

      const beforeLeft = handle().style.left;
      const beforeTop = handle().style.top;
      const last = view.dom.children[2].getBoundingClientRect();
      await triggerEvent(handle(), "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 20,
        clientY: 20,
      });
      await triggerEvent(handle(), "pointermove", {
        pointerId: 1,
        clientX: last.right + 100,
        clientY: last.bottom - 2,
      });

      assert.true(
        view.state.selection instanceof NodeSelection,
        "the block itself is selected, not a cursor inside it"
      );
      assert.strictEqual(
        view.state.selection.node.textContent,
        "First paragraph.",
        "and it is the block the handle belonged to"
      );

      assert.dom(".composer-drag-handle").hasClass("is-dragging");
      assert.strictEqual(
        handle().style.left,
        beforeLeft,
        "the handle remains in its horizontal rail"
      );
      assert.notStrictEqual(
        handle().style.top,
        beforeTop,
        "the handle follows the pointer vertically"
      );
      assert
        .dom(".composer-drag-handle__drop-indicator")
        .hasClass("--visible", "a full-width insertion marker is shown");
    });

    test("canceling a drag clears the editor's drag state", async function (assert) {
      const [editor] = await setupRichEditor(assert, DOC);
      const { view } = editor;

      await hoverBlock(view, 0);
      stubPointerCapture(handle());
      await triggerEvent(handle(), "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 20,
        clientY: 20,
      });
      await triggerEvent(handle(), "pointermove", {
        pointerId: 1,
        clientX: 40,
        clientY: 40,
      });
      await triggerEvent(handle(), "pointercancel", {
        pointerId: 1,
        clientX: 40,
        clientY: 40,
      });

      assert
        .dom(".ProseMirror")
        .doesNotHaveClass("is-dragging-block", "the editor leaves drag mode");
      assert
        .dom(".composer-drag-handle__drop-indicator")
        .doesNotHaveClass("--visible", "the insertion marker is cleared");
    });

    test("teardown during a drag clears the editor's drag state", async function (assert) {
      const [editor] = await setupRichEditor(assert, DOC);
      const { view } = editor;
      const editorDom = view.dom;

      await hoverBlock(view, 0);
      stubPointerCapture(handle());
      await triggerEvent(handle(), "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 20,
        clientY: 20,
      });
      await triggerEvent(handle(), "pointermove", {
        pointerId: 1,
        clientX: 40,
        clientY: 40,
      });
      assert.true(editorDom.classList.contains("is-dragging-block"));

      await clearRender();

      assert.false(
        editorDom.classList.contains("is-dragging-block"),
        "the detached editor does not retain external drag state"
      );
    });

    test("dragging at an edge scrolls and drops at the new position", async function (assert) {
      const [editor] = await setupRichEditor(assert, DOC);
      const { view } = editor;
      const scrollport = view.dom.parentElement;
      const first = view.dom.children[0];
      const third = view.dom.children[2];
      let thirdPos;
      let scrollTop = 0;

      view.state.doc.descendants((node, pos) => {
        if (node.textContent === "Third paragraph.") {
          thirdPos = pos;
        }
      });

      scrollport.style.overflowY = "auto";
      sinon.stub(scrollport, "scrollHeight").get(() => 300);
      sinon.stub(scrollport, "clientHeight").get(() => 100);
      sinon.stub(scrollport, "clientTop").get(() => 0);
      sinon
        .stub(scrollport, "scrollTop")
        .get(() => scrollTop)
        .set((value) => (scrollTop = Math.min(value, 64)));
      sinon.stub(scrollport, "getBoundingClientRect").returns({
        top: 0,
        right: 200,
        bottom: 100,
        left: 0,
        width: 200,
        height: 100,
      });
      sinon.stub(view.dom, "getBoundingClientRect").returns({
        top: 0,
        right: 200,
        bottom: 200,
        left: 0,
        width: 200,
        height: 200,
      });
      sinon.stub(first, "getBoundingClientRect").returns({
        top: 8,
        right: 200,
        bottom: 32,
        left: 0,
        width: 200,
        height: 24,
      });
      sinon.stub(third, "getBoundingClientRect").callsFake(() => ({
        top: 140 - scrollTop,
        right: 200,
        bottom: 164 - scrollTop,
        left: 0,
        width: 200,
        height: 24,
      }));
      sinon.stub(handle(), "offsetHeight").get(() => 24);
      sinon
        .stub(view, "posAtCoords")
        .onFirstCall()
        .returns({ pos: 1 })
        .returns({ pos: thirdPos + 1 });

      await hoverBlock(view, 0);
      stubPointerCapture(handle());
      const point = { pointerId: 1, clientX: 20, clientY: 99 };
      await triggerEvent(handle(), "pointerdown", {
        ...point,
        button: 0,
        clientY: 80,
      });
      await triggerEvent(handle(), "pointermove", point);
      await waitUntil(() => scrollTop === 64);

      assert.strictEqual(
        parseFloat(find(".composer-drag-handle__drop-indicator").style.top),
        100,
        "the indicator follows content while the pointer stays still"
      );

      await triggerEvent(handle(), "pointerup", point);

      assert.strictEqual(
        editor.value,
        "Second paragraph.\n\nThird paragraph.\n\nFirst paragraph.",
        "release uses the destination revealed by autoscroll"
      );
    });

    test("dropping it puts the block in its new place", async function (assert) {
      const [editor] = await setupRichEditor(assert, DOC);
      const { view } = editor;

      await hoverBlock(view, 0);
      stubPointerCapture(handle());

      const last = view.dom.children[2].getBoundingClientRect();
      const from = {
        button: 0,
        pointerId: 1,
        clientX: 20,
        clientY: 20,
      };
      const to = {
        pointerId: 1,
        clientX: last.left + 5,
        clientY: last.bottom - 2,
      };
      await triggerEvent(handle(), "pointerdown", from);
      await triggerEvent(handle(), "pointermove", to);
      assert
        .dom(".composer-drag-handle__drop-indicator")
        .hasClass("--visible", "the destination is visible before dropping");
      await triggerEvent(handle(), "pointerup", to);

      assert.false(
        editor.value.startsWith("First paragraph."),
        "the dragged block is no longer where it started"
      );
      assert.true(
        editor.value.includes("First paragraph."),
        "and it was moved rather than lost"
      );
      assert
        .dom(".composer-drag-handle__drop-indicator")
        .doesNotHaveClass("--visible", "the destination clears after dropping");
    });

    test("a block can be dragged upward", async function (assert) {
      const [editor] = await setupRichEditor(assert, DOC);
      const { view } = editor;

      await hoverBlock(view, 2);
      stubPointerCapture(handle());

      const first = view.dom.children[0].getBoundingClientRect();
      const from = {
        button: 0,
        pointerId: 1,
        clientX: 20,
        clientY: 80,
      };
      const to = {
        pointerId: 1,
        clientX: first.left + 5,
        clientY: first.top + 1,
      };
      await triggerEvent(handle(), "pointerdown", from);
      await triggerEvent(handle(), "pointermove", to);
      await triggerEvent(handle(), "pointerup", to);

      assert.true(
        editor.value.startsWith("Third paragraph.\n\nFirst paragraph."),
        "the last block is moved before the first"
      );
    });

    test("dropping outside the editor does not move the block", async function (assert) {
      const [editor] = await setupRichEditor(assert, DOC);
      const { view } = editor;

      await hoverBlock(view, 0);
      stubPointerCapture(handle());

      const editorBounds = view.dom.getBoundingClientRect();
      const from = {
        button: 0,
        pointerId: 1,
        clientX: 20,
        clientY: 20,
      };
      const outside = {
        pointerId: 1,
        clientX: editorBounds.left + 5,
        clientY: editorBounds.bottom + 50,
      };
      await triggerEvent(handle(), "pointerdown", from);
      await triggerEvent(handle(), "pointermove", outside);
      await triggerEvent(handle(), "pointerup", outside);

      assert.strictEqual(editor.value, DOC);
    });

    // float-kit does not mount in a rendering test, so what is covered here is
    // the registry the handle's menu is built from, and that its entries work.
    test("the registry offers the shared actions to any block", async function (assert) {
      const [editor] = await setupRichEditor(assert, DOC);
      const target = firstBlock(editor.view);

      assert.deepEqual(
        classNames(nodeActionsFor("paragraph", target)),
        [
          "composer-node-menu__move-down",
          "composer-node-menu__duplicate",
          "---",
          "composer-node-menu__delete",
        ],
        "a plain block gets keyboard-accessible movement and shared actions"
      );
    });

    test("duplicate copies the block", async function (assert) {
      const [editor] = await setupRichEditor(assert, DOC);
      const items = nodeActionsFor("paragraph", firstBlock(editor.view));

      items.find((i) => i.className.endsWith("duplicate")).action();
      await settled();

      assert.true(
        editor.value.startsWith("First paragraph.\n\nFirst paragraph."),
        `copied it in place, got: ${editor.value.slice(0, 40)}`
      );
    });

    test("delete removes the block", async function (assert) {
      const [editor] = await setupRichEditor(assert, DOC);
      const items = nodeActionsFor("paragraph", firstBlock(editor.view));

      items.find((i) => i.className === "composer-node-menu__delete").action();
      await settled();

      assert.false(editor.value.includes("First paragraph."));
      assert.true(editor.value.startsWith("Second paragraph."));
    });

    test("move down reorders a block without a pointer", async function (assert) {
      const [editor] = await setupRichEditor(assert, DOC);
      const items = nodeActionsFor("paragraph", firstBlock(editor.view));

      items.find((i) => i.className.endsWith("move-down")).action();
      await settled();

      assert.true(
        editor.value.startsWith("Second paragraph.\n\nFirst paragraph.")
      );
      assert.true(editor.view.state.selection instanceof NodeSelection);
      assert.strictEqual(
        editor.view.state.selection.node.textContent,
        "First paragraph.",
        "the moved block remains selected"
      );
    });

    test("nested item actions are scoped to their sibling list", async function (assert) {
      const [editor] = await setupRichEditor(assert, NESTED_DOC);
      const { view } = editor;
      let target;

      view.state.doc.descendants((node, pos) => {
        if (
          node.type.name === "list_item" &&
          node.textContent === "First nested"
        ) {
          target = { node, pos, view, pluginParams: {} };
        }
      });

      const items = nodeActionsFor("list_item", target);
      items.find((item) => item.className.endsWith("move-down")).action();
      await settled();

      assert.true(
        editor.value.indexOf("* Second nested") <
          editor.value.indexOf("* First nested"),
        "the action reorders nested siblings without moving the outer list"
      );
      assert.true(
        editor.value.startsWith("* Parent"),
        "the outer list item stays in place"
      );
    });

    test("crossing a short gap to the handle keeps it up", async function (assert) {
      const [editor] = await setupRichEditor(assert, DOC);
      const { view } = editor;

      await hoverBlock(view, 0);
      assert.dom(".composer-drag-handle").hasClass("--visible");

      view.dom.dispatchEvent(
        new PointerEvent("pointerleave", {
          bubbles: false,
          relatedTarget: null,
        })
      );
      handle().dispatchEvent(
        new PointerEvent("pointerenter", { bubbles: false })
      );
      await new Promise((resolve) => setTimeout(resolve, 250));
      await settled();

      assert
        .dom(".composer-drag-handle")
        .hasClass("--visible", "a transient gap does not dismiss the handle");

      handle().dispatchEvent(
        new PointerEvent("pointerleave", {
          bubbles: false,
          relatedTarget: null,
        })
      );
      await new Promise((resolve) => setTimeout(resolve, 250));
      await settled();

      assert
        .dom(".composer-drag-handle")
        .doesNotHaveClass(
          "--visible",
          "but leaving for anywhere else hides it"
        );
    });

    test("a pointer gap keeps the nearest block available", async function (assert) {
      const [editor] = await setupRichEditor(assert, DOC);
      const { view } = editor;

      await hoverBlock(view, 0);
      const firstTop = handle().style.top;
      const second = view.dom.children[1].getBoundingClientRect();
      sinon.stub(view, "posAtCoords").returns(null);

      view.dom.dispatchEvent(
        new PointerEvent("pointermove", {
          bubbles: true,
          clientX: second.left,
          clientY: second.top + second.height / 2,
        })
      );
      await settled();

      assert
        .dom(".composer-drag-handle")
        .hasClass("--visible", "the handle remains available in editor gaps");
      assert.notStrictEqual(
        handle().style.top,
        firstTop,
        "the handle resolves to the nearest block"
      );
    });
  }
);
