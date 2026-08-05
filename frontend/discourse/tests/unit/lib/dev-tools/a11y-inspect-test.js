import { computeAccessibleName } from "dom-accessibility-api";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  accessibleDescription,
  classifyCursor,
  compareCursors,
  composeUtterance,
  describeBarriers,
  describeContainment,
  describeElement,
  visualCursor,
} from "discourse/static/dev-tools/a11y/inspect";

/**
 * Oracle for the pure a11y inspection helpers (unit A1). Fixtures are plain
 * DOM inside #qunit-fixture; nothing here renders a component, so every
 * classification is a claim about markup alone.
 */
module("Unit | Lib | dev-tools | a11y-inspect", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.fixture = document.getElementById("qunit-fixture");
  });

  function combobox(fixture, { activeId, html }) {
    fixture.innerHTML = `
      <input role="combobox" id="cb" aria-controls="lb"
        ${activeId === undefined ? "" : `aria-activedescendant="${activeId}"`} />
      <ul role="listbox" id="lb">${html}</ul>
    `;
    return fixture.querySelector("#cb");
  }

  test("no aria-activedescendant classifies as absent", function (assert) {
    const focused = combobox(this.fixture, {
      html: `<li role="option" id="o1">one</li>`,
    });

    assert.deepEqual(classifyCursor(focused), {
      state: "absent",
      target: null,
      container: null,
    });
  });

  test("an id that resolves to nothing classifies as dangling", function (assert) {
    const focused = combobox(this.fixture, {
      activeId: "ghost",
      html: `<li role="option" id="o1">one</li>`,
    });

    const info = classifyCursor(focused);
    assert.strictEqual(info.state, "dangling");
    assert.strictEqual(info.target, null);
  });

  test("a target without an item role classifies as not_item", function (assert) {
    const focused = combobox(this.fixture, {
      activeId: "sep",
      html: `<li role="option" id="o1">one</li><li role="separator" id="sep"></li>`,
    });

    const info = classifyCursor(focused);
    assert.strictEqual(info.state, "not_item");
    assert.strictEqual(info.target?.id, "sep");
  });

  test("an option in a listbox classifies as ok with its option index", function (assert) {
    const focused = combobox(this.fixture, {
      activeId: "o2",
      html: `<li role="option" id="o1">one</li><li role="option" id="o2">two</li>`,
    });

    const info = classifyCursor(focused);
    assert.strictEqual(info.state, "ok");
    assert.strictEqual(info.index, 1);
    assert.strictEqual(info.container?.id, "lb");
  });

  test("the container role decides the item roles, not a listbox assumption", function (assert) {
    this.fixture.innerHTML = `
      <button id="trigger" aria-activedescendant="mi2" aria-controls="menu"></button>
      <div role="menu" id="menu">
        <div role="menuitem" id="mi1">alpha</div>
        <div role="menuitemcheckbox" id="mi2">beta</div>
      </div>
    `;

    const info = classifyCursor(this.fixture.querySelector("#trigger"));
    assert.strictEqual(info.state, "ok");
    assert.strictEqual(info.index, 1);
    assert.strictEqual(info.container?.id, "menu");
  });

  test("a portaled target resolves its container through the target's ancestry", function (assert) {
    this.fixture.innerHTML = `
      <input role="combobox" id="cb" aria-activedescendant="far"
        aria-controls="portal-lb" />
      <div id="elsewhere">
        <ul role="listbox" id="portal-lb"><li role="option" id="far">far</li></ul>
      </div>
    `;

    const info = classifyCursor(this.fixture.querySelector("#cb"));
    assert.strictEqual(info.state, "ok");
    assert.strictEqual(info.container?.id, "portal-lb");
  });

  test("a present-but-empty active-descendant is dangling, not absent", function (assert) {
    const focused = combobox(this.fixture, {
      activeId: "",
      html: `<li role="option" id="o1">one</li>`,
    });

    assert.strictEqual(classifyCursor(focused).state, "dangling");
  });

  test("a tablist resolves tab items like any composite", function (assert) {
    this.fixture.innerHTML = `
      <div id="outer" aria-activedescendant="t2" aria-controls="tabs"></div>
      <div role="tablist" id="tabs">
        <button role="tab" id="t1">one</button>
        <button role="tab" id="t2">two</button>
      </div>
    `;

    const info = classifyCursor(this.fixture.querySelector("#outer"));
    assert.strictEqual(info.state, "ok");
    assert.strictEqual(info.index, 1);
  });

  test("barriers reports tree-pruning ancestors nearest-first", function (assert) {
    this.fixture.innerHTML = `
      <div role="dialog" aria-modal="true">
        <div aria-hidden="true">
          <div inert>
            <span id="leaf">x</span>
          </div>
        </div>
      </div>
    `;

    assert.deepEqual(
      describeBarriers(this.fixture.querySelector("#leaf")),
      ["inert", "aria-hidden"],
      "the dialog and its modal flag are not barriers to what is inside them"
    );
  });

  // Every control in every modal sits under these. Counting them as barriers
  // flagged an entire composer session as broken.
  test("a dialog is not a barrier to its own contents", function (assert) {
    this.fixture.innerHTML = `
      <div role="dialog" aria-modal="true">
        <div popover="auto">
          <button id="leaf">Save</button>
        </div>
      </div>
    `;

    assert.deepEqual(
      describeBarriers(this.fixture.querySelector("#leaf")),
      [],
      "a reader inside the dialog reaches this perfectly well"
    );
  });

  test("an unobstructed element has no barriers", function (assert) {
    this.fixture.innerHTML = `<div><span id="leaf">x</span></div>`;

    assert.deepEqual(describeBarriers(this.fixture.querySelector("#leaf")), []);
  });

  test("containment distinguishes descendant, claimed, and unclaimed", function (assert) {
    this.fixture.innerHTML = `
      <div id="owner" aria-owns="away">
        <span id="inside"></span>
      </div>
      <div id="controller" aria-controls="away"></div>
      <div id="stranger"></div>
      <div id="away"><span id="remote"></span></div>
    `;
    const inside = this.fixture.querySelector("#inside");
    const remote = this.fixture.querySelector("#remote");

    assert.deepEqual(
      describeContainment(this.fixture.querySelector("#owner"), inside),
      { kind: "descendant" }
    );
    assert.deepEqual(
      describeContainment(this.fixture.querySelector("#owner"), remote),
      { kind: "claimed", via: ["aria-owns"] }
    );
    assert.deepEqual(
      describeContainment(this.fixture.querySelector("#controller"), remote),
      { kind: "claimed", via: ["aria-controls"] }
    );
    assert.deepEqual(
      describeContainment(this.fixture.querySelector("#stranger"), remote),
      { kind: "unclaimed" }
    );
    assert.deepEqual(
      describeContainment(this.fixture.querySelector("#stranger"), null),
      { kind: "none" }
    );
  });

  test("an utterance carries the accessible name, not the text content", function (assert) {
    this.fixture.innerHTML = `
      <span id="label-x">Tags</span>
      <ul role="listbox">
        <li role="option" id="opt" aria-labelledby="label-x"
          aria-posinset="3" aria-setsize="12" aria-selected="true">
          <span aria-hidden="true">#</span>irrelevant subtree text
        </li>
      </ul>
    `;

    assert.strictEqual(
      composeUtterance(this.fixture.querySelector("#opt")),
      "Tags, 3 of 12, selected"
    );
  });

  test("an utterance omits what the markup does not state", function (assert) {
    this.fixture.innerHTML = `
      <ul role="listbox"><li role="option" id="opt">plain</li></ul>
    `;

    assert.strictEqual(
      composeUtterance(this.fixture.querySelector("#opt")),
      "plain"
    );
  });

  test("a disabled item says so", function (assert) {
    this.fixture.innerHTML = `
      <ul role="listbox">
        <li role="option" id="opt" aria-disabled="true"
          aria-posinset="1" aria-setsize="2">alpha</li>
      </ul>
    `;

    assert.strictEqual(
      composeUtterance(this.fixture.querySelector("#opt")),
      "alpha, 1 of 2, disabled"
    );
  });

  test("an utterance carries the description a reader would speak", function (assert) {
    this.fixture.innerHTML = `
      <span id="hint">Press down arrow to select</span>
      <ul role="listbox">
        <li role="option" id="opt" aria-describedby="hint"
          aria-posinset="1" aria-setsize="2">alpha</li>
      </ul>
    `;

    assert.strictEqual(
      composeUtterance(this.fixture.querySelector("#opt")),
      "alpha, Press down arrow to select, 1 of 2",
      "the description lands between the name and the state"
    );
  });

  test("a description that adds something is kept", function (assert) {
    this.fixture.innerHTML = `
      <button id="fine" title="Closes the panel">Close</button>
      <button id="bare">Close</button>
    `;

    assert.strictEqual(
      accessibleDescription(this.fixture.querySelector("#fine")),
      "Closes the panel"
    );
    assert.strictEqual(
      accessibleDescription(this.fixture.querySelector("#bare")),
      "",
      "no description at all"
    );
  });

  // The real markup of the header's advanced-search link. Its children are all
  // aria-hidden, so the title IS the name and a reader says it once — the
  // library reports that title in both roles, and `textContent` is no help
  // because it counts the aria-hidden span the tree ignores.
  test("a title doing the naming is not also a description", function (assert) {
    this.fixture.innerHTML = `
      <a id="icon" href="/search?expanded=true" title="Open advanced search">
        <svg aria-hidden="true"><use href="#magnifying-glass"></use></svg>
        <span aria-hidden="true">…</span>
      </a>
    `;
    const link = this.fixture.querySelector("#icon");

    assert.strictEqual(
      computeAccessibleName(link),
      "Open advanced search",
      "the title named it"
    );
    assert.strictEqual(
      accessibleDescription(link),
      "",
      "so it describes nothing on top"
    );
    assert.strictEqual(
      composeUtterance(link),
      "Open advanced search",
      "and the utterance says it once"
    );
  });

  test("an element is described by tag and role, never by a generated id", function (assert) {
    this.fixture.innerHTML = `
      <input role="combobox" id="ember143" class="d-combobox__input"
        aria-label="Category" />
      <div id="real-id" class="thing"></div>
      <span id="ember9"></span>
    `;

    assert.strictEqual(
      describeElement(this.fixture.querySelector("#ember143")),
      "input · role=combobox · Category",
      "the accessible name beats an auto-generated id"
    );
    assert.strictEqual(
      describeElement(this.fixture.querySelector("#real-id")),
      "div · thing",
      "a class identifies an element with no name"
    );
    assert.strictEqual(
      describeElement(this.fixture.querySelector("#ember9")),
      "span",
      "a generated id is never the identity"
    );
    assert.strictEqual(describeElement(null), undefined);
  });

  test("a visual cursor is found by convention, within its own container", function (assert) {
    this.fixture.innerHTML = `
      <ul role="listbox" id="mine">
        <li role="option" id="a">alpha</li>
        <li role="option" id="b" class="--active">beta</li>
      </ul>
      <ul role="listbox" id="other">
        <li role="option" id="c" class="--active">gamma</li>
      </ul>
      <ul role="listbox" id="unmarked"><li role="option">delta</li></ul>
      <ul role="listbox" id="falsy">
        <li role="option" id="e" aria-current="false">epsilon</li>
      </ul>
    `;

    assert.strictEqual(
      visualCursor(this.fixture.querySelector("#mine"))?.id,
      "b",
      "a sibling composite does not answer for this one"
    );
    assert.strictEqual(
      visualCursor(this.fixture.querySelector("#unmarked")),
      null,
      "a composite marking nothing yields no cursor"
    );
    assert.strictEqual(
      visualCursor(this.fixture.querySelector("#falsy")),
      null,
      "aria-current=false is not a cursor"
    );
    assert.strictEqual(visualCursor(null), null);
  });

  test("cursor agreement never guesses from an absent half", function (assert) {
    this.fixture.innerHTML = `
      <ul role="listbox"><li role="option" id="a">a</li>
      <li role="option" id="b">b</li></ul>
    `;
    const a = this.fixture.querySelector("#a");
    const b = this.fixture.querySelector("#b");

    assert.strictEqual(compareCursors(a, a), "agree");
    assert.strictEqual(compareCursors(a, b), "diverged");
    assert.strictEqual(
      compareCursors(a, null),
      "unknown",
      "a missing visual cursor is not agreement"
    );
    assert.strictEqual(compareCursors(null, b), "unknown");
  });

  test("an ok cursor reports the size of the set it sits in", function (assert) {
    const focused = combobox(this.fixture, {
      activeId: "o2",
      html: `
        <li role="option" id="o1">one</li>
        <li role="option" id="o2">two</li>
        <li role="option" id="o3">three</li>
      `,
    });

    const cursor = classifyCursor(focused);
    assert.strictEqual(cursor.index, 1);
    assert.strictEqual(cursor.size, 3, "the set size comes from the container");
  });
});
