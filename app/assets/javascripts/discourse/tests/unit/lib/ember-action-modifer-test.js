import { module, test } from "qunit";
import { setupRenderingTest } from "ember-qunit";
import { click, doubleClick, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Unit | Lib | ember-action-modifer", function (hooks) {
  setupRenderingTest(hooks);

  test("`{{action}}` can target a function", async function (assert) {
    let i = 0;

    this.setProperties({
      onChildClick: () => this.set("childClicked", i++),
      childClicked: undefined,
    });

    await render(hbs`
      <button id="childButton" {{action this.onChildClick}} />
    `);

    await click("#childButton");

    assert.strictEqual(this.childClicked, 0);
  });

  test("`{{action}}` can target a method on the current context by name", async function (assert) {
    let i = 0;

    this.setProperties({
      onChildClick: () => this.set("childClicked", i++),
      childClicked: undefined,
    });

    await render(hbs`
      <button id="childButton" {{action 'onChildClick'}} />
    `);

    await click("#childButton");

    assert.strictEqual(this.childClicked, 0);
  });

  test("`{{action}}` will ignore clicks combined with modifier keys", async function (assert) {
    let i = 0;

    this.setProperties({
      onChildClick: () => this.set("childClicked", i++),
      childClicked: undefined,
    });

    await render(hbs`
      <button id="childButton" {{action 'onChildClick'}} />
    `);

    await click("#childButton", { ctrlKey: true });

    assert.strictEqual(this.childClicked, undefined);
  });

  test("`{{action}}` can specify an event other than `click` via `on`", async function (assert) {
    let i = 0;

    this.setProperties({
      onDblClick: () => this.set("dblClicked", i++),
      dblClicked: undefined,
    });

    await render(hbs`
      <button id="childButton" {{action this.onDblClick on='dblclick'}} />
    `);

    await doubleClick("#childButton");

    assert.strictEqual(this.dblClicked, 0);
  });
});
