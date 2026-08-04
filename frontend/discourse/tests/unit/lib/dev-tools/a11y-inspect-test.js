import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  classifyCursor,
  composeUtterance,
  describeBarriers,
  describeContainment,
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

    assert.deepEqual(describeBarriers(this.fixture.querySelector("#leaf")), [
      "inert",
      "aria-hidden",
      "aria-modal",
      "role=dialog",
    ]);
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
});
