import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import BlockReveal from "discourse/plugins/discourse-wireframe/discourse/lib/block-reveal";

// Builds a BlockReveal with controllable layout lookups. The two injected
// readers are only consulted by the tab-reveal path; the flash path needs
// neither, so they default to "nothing found".
function buildReveal({ located = null, layout = null } = {}) {
  return new BlockReveal({
    findEntryAndOutletSync: () => located,
    readResolvedLayout: () => layout,
  });
}

module("Unit | Discourse Wireframe | lib:block-reveal", function (hooks) {
  setupTest(hooks);

  // A detached fixture root the leaf's `document.querySelector` calls can find;
  // elements must be connected so the `afterRender` `isConnected` guard passes.
  let root;
  hooks.beforeEach(function () {
    root = document.createElement("div");
    document.body.appendChild(root);
  });
  hooks.afterEach(function () {
    root.remove();
  });

  function blockEl(key) {
    const el = document.createElement("div");
    el.setAttribute("data-wf-block-key", key);
    root.appendChild(el);
    return el;
  }

  module("flash", function () {
    // `settled` flushes the `discourseLater` removal too, so we observe the
    // transient class through spies rather than a post-settle `contains` check.
    test("flashes an already-rendered element", async function (assert) {
      const reveal = buildReveal();
      const el = blockEl("para:1");
      const addSpy = sinon.spy(el.classList, "add");

      reveal.flash("para:1");
      await settled();

      assert.true(
        addSpy.calledWith("--just-selected"),
        "applies the flash class"
      );
    });

    test("defers the flash until the element announces itself on mount", async function (assert) {
      const reveal = buildReveal();

      // No element for the key yet — the request is parked.
      reveal.flash("ghost:1");
      await settled();

      const el = blockEl("ghost:1");
      const addSpy = sinon.spy(el.classList, "add");
      reveal.notifyChromeInserted("ghost:1", el);
      await settled();

      assert.true(
        addSpy.calledWith("--just-selected"),
        "flashes once the element mounts"
      );
    });

    test("a new flash supersedes the previous element's pending removal", async function (assert) {
      const reveal = buildReveal();
      const a = blockEl("a:1");
      const b = blockEl("b:2");
      const aAdd = sinon.spy(a.classList, "add");
      const aRemove = sinon.spy(a.classList, "remove");
      const bAdd = sinon.spy(b.classList, "add");

      // Both requests fire before the runloop settles, so the second flash's
      // `afterRender` sees the first's timer still pending and strips it.
      reveal.flash("a:1");
      reveal.flash("b:2");
      await settled();

      assert.true(
        aAdd.calledWith("--just-selected"),
        "the first block flashed"
      );
      assert.true(
        aRemove.calledWith("--just-selected"),
        "the first flash was stripped when superseded"
      );
      assert.true(
        bAdd.calledWith("--just-selected"),
        "the second block flashed"
      );
    });
  });

  module("notifyChromeInserted", function () {
    test("ignores a key that isn't pending", async function (assert) {
      const reveal = buildReveal();
      const el = blockEl("other:1");
      const addSpy = sinon.spy(el.classList, "add");

      reveal.notifyChromeInserted("other:1", el);
      await settled();

      assert.false(
        addSpy.calledWith("--just-selected"),
        "an un-deferred mount does nothing"
      );
    });

    test("ignores an empty key", function (assert) {
      const reveal = buildReveal();
      // Just asserting it doesn't throw with no pending state.
      reveal.notifyChromeInserted("", document.createElement("div"));
      assert.true(true);
    });
  });

  module("reset", function () {
    test("drops a deferred flash so it can't replay later", async function (assert) {
      const reveal = buildReveal();
      reveal.flash("ghost:1"); // parked, awaiting a mount
      reveal.reset();

      const el = blockEl("ghost:1");
      const addSpy = sinon.spy(el.classList, "add");
      reveal.notifyChromeInserted("ghost:1", el);
      await settled();

      assert.false(
        addSpy.calledWith("--just-selected"),
        "the stale pending flash was cleared"
      );
    });

    test("is safe to call when idle", function (assert) {
      const reveal = buildReveal();
      reveal.reset();
      reveal.reset();
      assert.true(true, "idempotent, no throw");
    });
  });

  module("revealSelection — containing tabs", function () {
    // A tabs block wrapping a paragraph. String `block` refs make `entryKey`
    // resolve to `${block}:${__stableKey}` without a registry.
    const LAYOUT = [
      {
        block: "tabs",
        __stableKey: 1,
        children: [{ block: "para", __stableKey: 2 }],
      },
    ];

    function tabButton(panelKey, selected) {
      const btn = document.createElement("button");
      btn.setAttribute("data-wf-tab-panel-key", panelKey);
      btn.setAttribute("aria-selected", selected ? "true" : "false");
      root.appendChild(btn);
      return btn;
    }

    test("switches to an unselected ancestor tab on the path", function (assert) {
      const reveal = buildReveal({
        located: { entry: {}, outletName: "o" },
        layout: LAYOUT,
      });
      const btn = tabButton("tabs:1", false);
      let clicked = false;
      btn.addEventListener("click", () => (clicked = true));

      reveal.revealSelection("para:2");

      assert.true(clicked, "clicks the containing tab's button");
    });

    test("leaves an already-selected tab alone", function (assert) {
      const reveal = buildReveal({
        located: { entry: {}, outletName: "o" },
        layout: LAYOUT,
      });
      const btn = tabButton("tabs:1", true);
      let clicked = false;
      btn.addEventListener("click", () => (clicked = true));

      reveal.revealSelection("para:2");

      assert.false(clicked, "no redundant tab switch");
    });

    test("no-ops when the entry can't be located", function (assert) {
      const reveal = buildReveal({ located: null });
      const btn = tabButton("tabs:1", false);
      let clicked = false;
      btn.addEventListener("click", () => (clicked = true));

      reveal.revealSelection("para:2");

      assert.false(clicked, "nothing to reveal");
    });
  });
});
