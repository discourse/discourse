import { module, test } from "qunit";
import sinon from "sinon";
import { awaitVisualReadiness } from "discourse/tests/test-boot-ember-cli";

/**
 * Builds a stand-in for `document.fonts` whose `ready` promise the test
 * controls, so the gate can be observed while still pending.
 */
function fakeFontSet({ load = sinon.stub().resolves([]) } = {}) {
  let resolveReady;
  const ready = new Promise((resolve) => (resolveReady = resolve));
  return { fonts: { load, ready }, resolveReady };
}

/**
 * Reports whether a promise has settled without waiting on it.
 */
async function isSettled(promise) {
  const pending = Symbol("pending");
  return (await Promise.race([promise, pending])) !== pending;
}

module("Unit | Test boot | visual readiness", function (hooks) {
  hooks.beforeEach(function () {
    this.element = document.createElement("div");
    this.element.style.font = 'bold 17px "Readiness Probe Face"';
    document.body.append(this.element);
  });

  hooks.afterEach(function () {
    this.element.remove();
  });

  test("every app stylesheet is a boot prerequisite of the test entrypoint", function (assert) {
    const entrypoint = document.querySelector(
      'script[data-discourse-entrypoint="test-entrypoint"]'
    );
    const stylesheets = [
      ...document.querySelectorAll('link[rel="stylesheet"]'),
    ];
    const targets = stylesheets.map((link) => link.dataset.target);

    assert.true(
      document.body.contains(entrypoint),
      "the test entrypoint script is in the body"
    );
    assert.true(targets.includes("common"), "the common stylesheet is linked");

    for (const link of stylesheets) {
      // The runner's own restyling sheet is cosmetic and must stay last in the
      // body so it follows the stylesheet the runner injects at runtime.
      if (link.dataset.target === "qunit-custom") {
        continue;
      }

      // A head stylesheet blocks the deferred module script in the body; any
      // non-head element before it demotes the rest of the head to the body,
      // where it blocks nothing.
      assert.strictEqual(
        link.parentElement,
        document.head,
        `${link.dataset.target ?? link.href} is linked from the head`
      );
    }
  });

  test("requests the computed font of the given element before waiting on the font set", async function (assert) {
    const { fonts, resolveReady } = fakeFontSet();
    const computed = getComputedStyle(this.element);

    const readiness = awaitVisualReadiness({ fonts, element: this.element });

    assert.true(
      fonts.load.calledOnceWith(
        `${computed.fontWeight} ${computed.fontSize} ${computed.fontFamily}`
      ),
      "the element's computed font is requested explicitly"
    );

    resolveReady();
    await readiness;
  });

  test("does not resolve until the font set reports ready", async function (assert) {
    const { fonts, resolveReady } = fakeFontSet();

    const readiness = awaitVisualReadiness({ fonts, element: this.element });
    await Promise.resolve();

    assert.false(
      await isSettled(readiness),
      "readiness is still pending while the font set loads"
    );

    resolveReady();
    await readiness;
    assert.true(await isSettled(readiness), "readiness resolves once ready");
  });

  test("still resolves when the font request itself fails", async function (assert) {
    const { fonts, resolveReady } = fakeFontSet({
      load: sinon.stub().rejects(new Error("no such face")),
    });

    const readiness = awaitVisualReadiness({ fonts, element: this.element });
    resolveReady();
    await readiness;

    assert.true(
      await isSettled(readiness),
      "a missing face must not block the test run"
    );
  });
});
