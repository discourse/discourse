import { module, test } from "qunit";
import sinon from "sinon";
import richEditorSelectionToolbar from "discourse/plugins/chat/discourse/lib/rich-editor-selection-toolbar";

module("Unit | Chat | rich editor selection toolbar", function () {
  test("destroys an obsolete menu when a newer selection is already opening", async function (assert) {
    const pending = [];
    const menu = {
      show: () => new Promise((resolve) => pending.push(resolve)),
    };
    const dom = document.createElement("div");
    const view = {
      dom,
      hasFocus: () => true,
      state: {
        selection: {
          empty: false,
          $from: { parent: { inlineContent: true, type: { spec: {} } } },
          $head: { marks: () => [] },
        },
        schema: { marks: {} },
      },
    };
    const plugin = richEditorSelectionToolbar(() => ({})).plugins({
      pmState: {
        Plugin: class {
          constructor(spec) {
            return spec;
          }
        },
      },
      getContext: () => ({ menu }),
    });
    const toolbar = plugin.view(view);
    const oldInstance = { destroy: sinon.spy() };
    const newInstance = { destroy: sinon.spy() };

    try {
      toolbar.update(view);
      plugin.props.handleDOMEvents.blur(view, { relatedTarget: document.body });
      toolbar.update(view);
      pending[0](oldInstance);
      await Promise.resolve();
      assert.true(
        oldInstance.destroy.calledOnce,
        "the obsolete result cannot replace the pending menu"
      );
      pending[1](newInstance);
      await Promise.resolve();
      assert.false(
        newInstance.destroy.called,
        "the current result is retained"
      );
      toolbar.destroy();
      assert.true(
        newInstance.destroy.calledOnce,
        "teardown destroys the current menu"
      );
    } finally {
      toolbar.destroy();
    }
  });

  test("destroys a menu that finishes opening after editor teardown", async function (assert) {
    let resolve;
    const plugin = richEditorSelectionToolbar(() => ({})).plugins({
      pmState: {
        Plugin: class {
          constructor(spec) {
            return spec;
          }
        },
      },
      getContext: () => ({
        menu: { show: () => new Promise((r) => (resolve = r)) },
      }),
    });
    const view = {
      dom: document.createElement("div"),
      hasFocus: () => true,
      state: {
        selection: {
          empty: false,
          $from: { parent: { inlineContent: true, type: { spec: {} } } },
          $head: { marks: () => [] },
        },
        schema: { marks: {} },
      },
    };
    const toolbar = plugin.view(view);
    toolbar.update(view);
    toolbar.destroy();
    const instance = { destroy: sinon.spy() };
    resolve(instance);
    await Promise.resolve();
    assert.true(instance.destroy.calledOnce);
  });
});
