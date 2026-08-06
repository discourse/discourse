import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { beginPass } from "discourse/static/dev-tools/a11y/dom";

/**
 * Oracle for the per-pass computed cache (unit 1b).
 *
 * Two claims, and every test below serves one of them.
 *
 * The first is that a pass is a *snapshot*. The panel freezes findings at
 * record time and renders them much later, so a value read twice inside one
 * pass has to answer the same both times, and the DOM moving underneath must
 * not make an already-recorded row disagree with itself.
 *
 * The second is that this module, not its callers, owns the gaps in
 * `dom-accessibility-api`. It ignores `inert` outright, and it excludes CSS
 * `content` from every computed name unless asked not to. Both defaults are
 * silent: nothing throws, nothing warns, the wrong answer just looks like an
 * answer. Callers must never have to remember either one.
 */
module("Unit | Lib | dev-tools | a11y-dom", function (hooks) {
  setupTest(hooks);

  let hosts;

  hooks.beforeEach(function () {
    hosts = [];
  });

  hooks.afterEach(function () {
    hosts.forEach((host) => host.remove());
  });

  // Attached to the real document: a computed style is meaningless detached,
  // and both the hidden rules and the pseudo-element rule read one.
  function fixture(html) {
    const host = document.createElement("div");
    host.innerHTML = html;
    document.body.appendChild(host);
    hosts.push(host);

    return host;
  }

  test("a pass computes the accessible name", function (assert) {
    const host = fixture(`<button aria-label="Save draft"></button>`);

    assert.strictEqual(
      beginPass().name(host.querySelector("button")),
      "Save draft"
    );
  });

  // `computedStyleSupportsPseudoElements` defaults to false, so a bare
  // `computeAccessibleName` call returns "" here. That is the whole name of an
  // icon-only control whose glyph comes from CSS, and the panel would report
  // every one of them as unnamed.
  test("a name supplied by CSS content is not lost", function (assert) {
    const host = fixture(`
      <style>.a11y-fixture-glyph::before { content: "Reply"; }</style>
      <button class="a11y-fixture-glyph"></button>
    `);

    assert.strictEqual(
      beginPass().name(host.querySelector("button")),
      "Reply",
      "the pass opts into pseudo-element content"
    );
  });

  test("a pass is a snapshot: a name does not move under it", function (assert) {
    const button = fixture(
      `<button aria-label="Before"></button>`
    ).querySelector("button");
    const pass = beginPass();

    assert.strictEqual(pass.name(button), "Before");

    button.setAttribute("aria-label", "After");

    assert.strictEqual(
      pass.name(button),
      "Before",
      "the pass answers what it read"
    );
    assert.strictEqual(
      beginPass().name(button),
      "After",
      "and a new pass reads the DOM again"
    );
  });

  test("distinct elements do not share a cache slot", function (assert) {
    const host = fixture(`
      <button aria-label="First"></button>
      <button aria-label="Second"></button>
    `);
    const [first, second] = host.querySelectorAll("button");
    const pass = beginPass();

    assert.strictEqual(pass.name(first), "First");
    assert.strictEqual(pass.name(second), "Second");
    assert.strictEqual(
      pass.name(first),
      "First",
      "and the first still answers"
    );
  });

  // Whether a description equal to the name is worth showing is a reporting
  // decision, and it is made against the name. A cache that dropped it here
  // would delete the evidence before anything could decide.
  test("the description is raw, including when it equals the name", function (assert) {
    const host = fixture(`
      <button aria-label="Save" aria-describedby="a11y-fixture-hint"></button>
      <span id="a11y-fixture-hint">Save</span>
    `);

    assert.strictEqual(
      beginPass().description(host.querySelector("button")),
      "Save"
    );
  });

  // Reading `role` off the attribute misses every element that carries its role
  // implicitly, which is most of them.
  test("the role is computed, not read off the attribute", function (assert) {
    const host = fixture(`
      <ul><li>one</li></ul>
      <div role="listbox"><div role="option">two</div></div>
    `);
    const pass = beginPass();

    assert.strictEqual(pass.role(host.querySelector("ul")), "list");
    assert.strictEqual(pass.role(host.querySelector("li")), "listitem");
    assert.strictEqual(
      pass.role(host.querySelector("[role='listbox']")),
      "listbox",
      "an explicit role still wins"
    );
  });

  test("an element the tree excludes is hidden, and so is its subtree", function (assert) {
    const host = fixture(`
      <div style="display: none"><button>hidden</button></div>
      <div aria-hidden="true"><button>also hidden</button></div>
    `);
    const [styled, ariaHidden] = host.querySelectorAll("div");
    const pass = beginPass();

    assert.true(pass.hidden(styled));
    assert.true(pass.hidden(styled.querySelector("button")));
    assert.true(pass.hidden(ariaHidden));
    assert.true(pass.hidden(ariaHidden.querySelector("button")));
  });

  test("a visible element is not hidden", function (assert) {
    const host = fixture(`<div><button>visible</button></div>`);
    const pass = beginPass();

    assert.false(pass.hidden(host.querySelector("div")));
    assert.false(pass.hidden(host.querySelector("button")));
  });

  // `dom-accessibility-api` does not implement `inert` at all — the string does
  // not appear anywhere in the package. Everything behind a modal backdrop
  // therefore reports as perfectly readable unless this module adds it.
  test("inert is hidden, though the library does not implement it", function (assert) {
    const host = fixture(`<div inert><button>behind a backdrop</button></div>`);
    const pass = beginPass();

    assert.true(pass.hidden(host.querySelector("div")), "the inert element");
    assert.true(
      pass.hidden(host.querySelector("button")),
      "and everything under it"
    );
  });

  test("a pass is a snapshot for hidden too", function (assert) {
    const button = fixture(`<button>visible</button>`).querySelector("button");
    const pass = beginPass();

    assert.false(pass.hidden(button));

    button.setAttribute("aria-hidden", "true");

    assert.false(
      pass.hidden(button),
      "a finding already recorded does not change its mind"
    );
    assert.true(beginPass().hidden(button), "a new pass sees the change");
  });

  // Closing a gap the implementer reported: the snapshot rule was pinned for
  // `name` and `hidden` only, so a cache covering just those two would satisfy
  // the oracle while leaving two readers live. Every reader on a pass answers as
  // of the same instant, or a recorded row is a composite of two moments.
  test("a pass is a snapshot for every reader, not only the pinned two", function (assert) {
    const host = fixture(`
      <div role="listbox" aria-describedby="a11y-fixture-note">x</div>
      <span id="a11y-fixture-note">Before</span>
    `);
    const subject = host.querySelector("[role]");
    const pass = beginPass();

    assert.strictEqual(pass.role(subject), "listbox");
    assert.strictEqual(pass.description(subject), "Before");

    subject.setAttribute("role", "menu");
    host.querySelector("#a11y-fixture-note").textContent = "After";

    assert.strictEqual(pass.role(subject), "listbox", "role held");
    assert.strictEqual(pass.description(subject), "Before", "description held");

    const later = beginPass();
    assert.strictEqual(later.role(subject), "menu", "and a new pass moves on");
    assert.strictEqual(later.description(subject), "After");
  });
});
