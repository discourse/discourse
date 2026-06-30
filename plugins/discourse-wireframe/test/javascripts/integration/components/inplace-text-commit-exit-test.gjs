import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import {
  render,
  settled,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import {
  _renderBlocks,
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import Layout from "discourse/blocks/builtin/layout";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import InplaceTextController from "discourse/plugins/discourse-wireframe/discourse/components/editor/inplace-text-controller";
import { entryKey } from "discourse/plugins/discourse-wireframe/discourse/lib/mutate-layout";
import { setupBlockLayoutDraftsStub } from "../../helpers/stub-block-layout-drafts";
import { queryOf } from "../../helpers/wireframe-peers";

// A two-field block stands in for a multi-field rich block (e.g. a media-card):
// Tab walks title -> subtitle -> exit. A single-field block covers the heading
// case (Tab commits + exits immediately).
@block("wf:cee-card", {
  args: { title: { type: "string" }, subtitle: { type: "string" } },
})
class Card extends Component {
  <template>
    <span>{{@title}}{{@subtitle}}</span>
  </template>
}

@block("wf:cee-leaf", { args: { text: { type: "string" } } })
class Leaf extends Component {
  <template>
    <span>{{@text}}</span>
  </template>
}

const OUTLET = "homepage-blocks";

// The outside-click handler defers its commit one frame (it lets a sibling
// click handler that may have transitioned the session win first), so a click
// assertion has to wait a frame before checking the session state.
function flushRaf() {
  return new Promise((resolve) => requestAnimationFrame(() => resolve()));
}

module(
  "Integration | discourse-wireframe | in-place text commit / exit",
  function (hooks) {
    setupRenderingTest(hooks);
    setupBlockLayoutDraftsStub(hooks);

    hooks.afterEach(function () {
      getOwner(this)?.lookup("service:wireframe-inplace-text")?.stop({
        commit: false,
      });
      this.editor?.exit();
      _resetOutletLayoutsForTesting();
    });

    // Registers a layout (a Card + a Leaf under a root Layout) so the service
    // can locate entries by key, then returns the editor plus the two entry
    // keys. Callers render the editable spans + controller themselves so the
    // gjs template can close over the keys.
    async function prepare(owner) {
      await _renderBlocks(
        OUTLET,
        [
          {
            block: Layout,
            args: {},
            children: [
              { block: Card, args: { title: "T", subtitle: "S" } },
              { block: Leaf, args: { text: "L" } },
            ],
          },
        ],
        owner
      );
      const editor = owner.lookup("service:wireframe-workspace");
      const inlineEdit = owner.lookup("service:wireframe-inplace-text");
      editor.siteSettings.wireframe_enabled = true;
      logIn(owner);
      editor.enter();

      const inner = queryOf(editor).readResolvedLayout(OUTLET)[0];
      return {
        editor,
        inlineEdit,
        cardKey: entryKey(inner.children[0]),
        leafKey: entryKey(inner.children[1]),
      };
    }

    // Bolds the whole (selected-on-mount) doc so the committed value becomes
    // doc-JSON rather than the seed string — a clear signal the PM doc actually
    // flowed back into `entry.args` on exit (a commit, not a revert).
    function boldAll(inlineEdit) {
      inlineEdit.controller.toggleMark("strong");
    }

    function argOf(editor, key, name) {
      return queryOf(editor).findEntryAndOutletSync(key)?.entry?.args?.[name];
    }

    test("Tab walks to the next rich-inline field on the same block", async function (assert) {
      const { editor, inlineEdit, cardKey, leafKey } = await prepare(
        getOwner(this)
      );
      this.editor = editor;

      await render(
        <template>
          <div class="card-block" data-wf-block-key={{cardKey}}>
            <span
              class="f-title"
              data-wf-rich-text-arg="title"
              data-block-arg-schema="heading"
            ></span>
            <span
              class="f-subtitle"
              data-wf-rich-text-arg="subtitle"
              data-block-arg-schema="heading"
            ></span>
          </div>
          <div class="leaf-block" data-wf-block-key={{leafKey}}>
            <span
              class="f-text"
              data-wf-rich-text-arg="text"
              data-block-arg-schema="heading"
            ></span>
          </div>
          <InplaceTextController />
        </template>
      );

      await inlineEdit.start(cardKey, "title");
      await settled();
      assert.strictEqual(
        inlineEdit.argName,
        "title",
        "session opened on the first field"
      );

      await triggerKeyEvent(".wf-rich-text-editor", "keydown", "Tab");
      // The Tab keymap fires the (async) start() for the next field without
      // awaiting it; flush a frame so the session transition lands.
      await flushRaf();
      await settled();

      assert.true(inlineEdit.isActive, "still editing after Tab");
      assert.strictEqual(
        inlineEdit.argName,
        "subtitle",
        "Tab moved to the next field on the same block"
      );
    });

    test("Tab past the last field commits and exits", async function (assert) {
      const { editor, inlineEdit, cardKey, leafKey } = await prepare(
        getOwner(this)
      );
      this.editor = editor;

      await render(
        <template>
          <div class="card-block" data-wf-block-key={{cardKey}}>
            <span
              class="f-title"
              data-wf-rich-text-arg="title"
              data-block-arg-schema="heading"
            ></span>
            <span
              class="f-subtitle"
              data-wf-rich-text-arg="subtitle"
              data-block-arg-schema="heading"
            ></span>
          </div>
          <div class="leaf-block" data-wf-block-key={{leafKey}}>
            <span
              class="f-text"
              data-wf-rich-text-arg="text"
              data-block-arg-schema="heading"
            ></span>
          </div>
          <InplaceTextController />
        </template>
      );

      await inlineEdit.start(cardKey, "subtitle");
      await settled();
      boldAll(inlineEdit);
      await settled();

      await triggerKeyEvent(".wf-rich-text-editor", "keydown", "Tab");

      assert.false(
        inlineEdit.isActive,
        "Tab past the last field exited the session"
      );
      assert.strictEqual(
        typeof argOf(editor, cardKey, "subtitle"),
        "object",
        "the edited (formatted) value was committed back to the entry"
      );
    });

    test("Shift-Tab past the first field commits and exits", async function (assert) {
      const { editor, inlineEdit, cardKey, leafKey } = await prepare(
        getOwner(this)
      );
      this.editor = editor;

      await render(
        <template>
          <div class="card-block" data-wf-block-key={{cardKey}}>
            <span
              class="f-title"
              data-wf-rich-text-arg="title"
              data-block-arg-schema="heading"
            ></span>
            <span
              class="f-subtitle"
              data-wf-rich-text-arg="subtitle"
              data-block-arg-schema="heading"
            ></span>
          </div>
          <div class="leaf-block" data-wf-block-key={{leafKey}}>
            <span
              class="f-text"
              data-wf-rich-text-arg="text"
              data-block-arg-schema="heading"
            ></span>
          </div>
          <InplaceTextController />
        </template>
      );

      await inlineEdit.start(cardKey, "title");
      await settled();
      boldAll(inlineEdit);
      await settled();

      await triggerKeyEvent(".wf-rich-text-editor", "keydown", "Tab", {
        shiftKey: true,
      });

      assert.false(
        inlineEdit.isActive,
        "Shift-Tab past the first field exited the session"
      );
      assert.strictEqual(
        typeof argOf(editor, cardKey, "title"),
        "object",
        "the edited (formatted) value was committed back to the entry"
      );
    });

    test("Tab in a single-field block commits and exits", async function (assert) {
      const { editor, inlineEdit, cardKey, leafKey } = await prepare(
        getOwner(this)
      );
      this.editor = editor;

      await render(
        <template>
          <div class="card-block" data-wf-block-key={{cardKey}}>
            <span
              class="f-title"
              data-wf-rich-text-arg="title"
              data-block-arg-schema="heading"
            ></span>
          </div>
          <div class="leaf-block" data-wf-block-key={{leafKey}}>
            <span
              class="f-text"
              data-wf-rich-text-arg="text"
              data-block-arg-schema="heading"
            ></span>
          </div>
          <InplaceTextController />
        </template>
      );

      await inlineEdit.start(leafKey, "text");
      await settled();
      boldAll(inlineEdit);
      await settled();

      await triggerKeyEvent(".wf-rich-text-editor", "keydown", "Tab");

      assert.false(
        inlineEdit.isActive,
        "Tab in a single-field block exited the session"
      );
      assert.strictEqual(
        typeof argOf(editor, leafKey, "text"),
        "object",
        "the edited (formatted) value was committed back to the entry"
      );
    });

    test("clicking elsewhere on the same block commits and exits", async function (assert) {
      const { editor, inlineEdit, cardKey, leafKey } = await prepare(
        getOwner(this)
      );
      this.editor = editor;

      await render(
        <template>
          <div class="card-block" data-wf-block-key={{cardKey}}>
            <span
              class="f-title"
              data-wf-rich-text-arg="title"
              data-block-arg-schema="heading"
            ></span>
            <span
              class="f-subtitle"
              data-wf-rich-text-arg="subtitle"
              data-block-arg-schema="heading"
            ></span>
            <span class="card-padding">padding</span>
          </div>
          <div class="leaf-block" data-wf-block-key={{leafKey}}>
            <span
              class="f-text"
              data-wf-rich-text-arg="text"
              data-block-arg-schema="heading"
            ></span>
          </div>
          <InplaceTextController />
        </template>
      );

      await inlineEdit.start(cardKey, "title");
      await settled();
      boldAll(inlineEdit);
      await settled();

      // The padding sits inside the editing block but is NOT a rich-inline
      // field region, so it must commit + exit (not stay, as it did before).
      await triggerEvent(".card-padding", "mousedown");
      await flushRaf();
      await settled();

      assert.false(
        inlineEdit.isActive,
        "clicking off the text on the same block exited the session"
      );
      assert.strictEqual(
        typeof argOf(editor, cardKey, "title"),
        "object",
        "the edit was committed on exit"
      );
    });

    test("clicking another field region on the same block does not exit", async function (assert) {
      const { editor, inlineEdit, cardKey, leafKey } = await prepare(
        getOwner(this)
      );
      this.editor = editor;

      await render(
        <template>
          <div class="card-block" data-wf-block-key={{cardKey}}>
            <span
              class="f-title"
              data-wf-rich-text-arg="title"
              data-block-arg-schema="heading"
            ></span>
            <span
              class="f-subtitle"
              data-wf-rich-text-arg="subtitle"
              data-block-arg-schema="heading"
            ></span>
          </div>
          <div class="leaf-block" data-wf-block-key={{leafKey}}>
            <span
              class="f-text"
              data-wf-rich-text-arg="text"
              data-block-arg-schema="heading"
            ></span>
          </div>
          <InplaceTextController />
        </template>
      );

      await inlineEdit.start(cardKey, "title");
      await settled();

      // Mousedown on another rich-inline field region: the chrome's own click
      // handler transitions the session via start(); the outside-click handler
      // must NOT race in and stop it. With no chrome wired here, the session
      // simply stays on the current field — proving no spurious exit.
      await triggerEvent(".f-subtitle", "mousedown");
      await flushRaf();
      await settled();

      assert.true(
        inlineEdit.isActive,
        "clicking another field region did not exit the session"
      );
      assert.strictEqual(
        inlineEdit.argName,
        "title",
        "no spurious exit transition fired"
      );
    });

    test("clicking the block toolbar keeps the session active", async function (assert) {
      const { editor, inlineEdit, cardKey, leafKey } = await prepare(
        getOwner(this)
      );
      this.editor = editor;

      await render(
        <template>
          <div class="card-block" data-wf-block-key={{cardKey}}>
            <span
              class="f-title"
              data-wf-rich-text-arg="title"
              data-block-arg-schema="heading"
            ></span>
          </div>
          <div class="leaf-block" data-wf-block-key={{leafKey}}>
            <span
              class="f-text"
              data-wf-rich-text-arg="text"
              data-block-arg-schema="heading"
            ></span>
          </div>
          <div class="wireframe-block-toolbar">
            <button type="button" class="tb-btn">B</button>
          </div>
          <InplaceTextController />
        </template>
      );

      await inlineEdit.start(cardKey, "title");
      await settled();

      await triggerEvent(".tb-btn", "mousedown");
      await flushRaf();
      await settled();

      assert.true(
        inlineEdit.isActive,
        "clicking a format toolbar button stayed in the edit session"
      );
    });

    test("Escape commits and exits", async function (assert) {
      const { editor, inlineEdit, cardKey, leafKey } = await prepare(
        getOwner(this)
      );
      this.editor = editor;

      await render(
        <template>
          <div class="card-block" data-wf-block-key={{cardKey}}>
            <span
              class="f-title"
              data-wf-rich-text-arg="title"
              data-block-arg-schema="heading"
            ></span>
          </div>
          <div class="leaf-block" data-wf-block-key={{leafKey}}>
            <span
              class="f-text"
              data-wf-rich-text-arg="text"
              data-block-arg-schema="heading"
            ></span>
          </div>
          <InplaceTextController />
        </template>
      );

      await inlineEdit.start(cardKey, "title");
      await settled();
      boldAll(inlineEdit);
      await settled();

      await triggerKeyEvent(".wf-rich-text-editor", "keydown", "Escape");

      assert.false(inlineEdit.isActive, "Escape exited the session");
      assert.strictEqual(
        typeof argOf(editor, cardKey, "title"),
        "object",
        "Escape committed the edit"
      );
    });
  }
);
