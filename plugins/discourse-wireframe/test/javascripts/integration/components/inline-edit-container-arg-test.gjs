import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import {
  _renderBlocks,
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import Layout from "discourse/blocks/builtin/layout";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import InlineEditController from "discourse/plugins/discourse-wireframe/discourse/components/editor/inline-edit-controller";
import { entryKey } from "discourse/plugins/discourse-wireframe/discourse/lib/mutate-layout";
import { setupBlockLayoutDraftsStub } from "../../helpers/stub-block-layout-drafts";

@block("wf:cae-test-leaf", { args: { title: { type: "string" } } })
class Leaf extends Component {
  <template>
    <span>{{@title}}</span>
  </template>
}

const OUTLET = "homepage-blocks";

module(
  "Integration | discourse-wireframe | inline-edit container-arg reactivity",
  function (hooks) {
    setupRenderingTest(hooks);
    setupBlockLayoutDraftsStub(hooks);

    hooks.afterEach(function () {
      this.editor?.exit();
      _resetOutletLayoutsForTesting();
    });

    // Regression for the value-bleed: the controller's `activeRendererEl` is
    // `@cached`. It once short-circuited on the (untracked) container-arg
    // context, so the cache captured no tracked dependency and never
    // invalidated — ProseMirror stayed mounted on the FIRST child's element and
    // later commits wrote its content to whatever the session had moved to (the
    // tab-label value bled into other tabs / paragraphs). This asserts the
    // getter recomputes to the new child's element when the session moves.
    test("activeRendererEl recomputes when the container-arg session moves to another child", async function (assert) {
      await _renderBlocks(
        OUTLET,
        [
          {
            block: Layout,
            args: {},
            children: [
              { block: Leaf, args: { title: "A" } },
              { block: Leaf, args: { title: "B" } },
            ],
          },
        ],
        getOwner(this)
      );
      this.editor = getOwner(this).lookup("service:wireframe");
      this.editor.siteSettings.wireframe_enabled = true;
      logIn(getOwner(this));
      this.editor.enter();

      // Our single root Layout satisfies the outlet's single-root-layout
      // invariant, so `enter()` adds no extra wrapper: the resolved layout's
      // first entry IS our Layout, and the two leaves are its children.
      const inner = this.editor.layoutQuery.readResolvedLayout(OUTLET)[0];
      const keyA = entryKey(inner.children[0]);
      const keyB = entryKey(inner.children[1]);

      // Two editable hosts (one per child) standing in for the label spans a
      // parent renders, plus the controller that resolves and mounts into them.
      await render(
        <template>
          <span
            data-wf-container-arg-key={{keyA}}
            data-wf-container-arg-namespace="tab"
            data-wf-container-arg-field="label"
          >
            <span class="host-a" data-wf-inline-edit-arg="label"></span>
          </span>
          <span
            data-wf-container-arg-key={{keyB}}
            data-wf-container-arg-namespace="tab"
            data-wf-container-arg-field="label"
          >
            <span class="host-b" data-wf-inline-edit-arg="label"></span>
          </span>
          <InlineEditController />
        </template>
      );

      const controller = this.editor.inlineEdit.controller;
      assert.true(Boolean(controller), "the inline-edit controller registered");

      await this.editor.inlineEdit.startContainerArg(keyA, "tab", "label");
      await settled();
      const elA = controller.activeRendererEl;
      assert
        .dom(elA)
        .hasClass("host-a", "session A resolves child A's editable");

      await this.editor.inlineEdit.startContainerArg(keyB, "tab", "label");
      await settled();
      const elB = controller.activeRendererEl;
      assert
        .dom(elB)
        .hasClass(
          "host-b",
          "session B resolves child B's editable — the cache recomputed"
        );
      assert.notStrictEqual(
        elA,
        elB,
        "the cached element did not stick on the first target (the bleed)"
      );

      this.editor.inlineEdit.stop({ commit: false });
    });
  }
);
