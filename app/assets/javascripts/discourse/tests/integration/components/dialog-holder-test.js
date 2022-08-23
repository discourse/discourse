import I18n from "I18n";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render, settled, triggerKeyEvent } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { query } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | dialog-holder", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.dialog = this.container.lookup("service:dialog");
  });

  test("basics", async function (assert) {
    await render(hbs`<DialogHolder />`);
    assert.ok(query("#dialog-holder"), "element is in DOM");
    assert.strictEqual(
      query("#dialog-holder").innerText.trim(),
      "",
      "dialog is empty by default"
    );

    this.dialog.alert({
      message: "This is an error",
    });
    await settled();

    assert.ok(
      query(".dialog-overlay").offsetWidth > 0,
      true,
      "overlay is visible"
    );
    assert.strictEqual(
      query(".dialog-body").innerText.trim(),
      "This is an error",
      "dialog has error message"
    );

    // dismiss by clicking on overlay
    await click(".dialog-overlay");

    assert.ok(query("#dialog-holder"), "element is still in DOM");
    assert.strictEqual(
      query(".dialog-overlay").offsetWidth,
      0,
      "overlay is not visible"
    );
    assert.strictEqual(
      query("#dialog-holder").innerText.trim(),
      "",
      "dialog is empty"
    );
  });

  test("basics - dismiss using Esc", async function (assert) {
    await render(hbs`<DialogHolder />`);
    assert.ok(query("#dialog-holder"), "element is in DOM");
    assert.strictEqual(
      query("#dialog-holder").innerText.trim(),
      "",
      "dialog is empty by default"
    );

    this.dialog.alert({
      message: "This is an error",
    });
    await settled();

    assert.ok(
      query(".dialog-overlay").offsetWidth > 0,
      true,
      "overlay is visible"
    );
    assert.strictEqual(
      query(".dialog-body").innerText.trim(),
      "This is an error",
      "dialog has error message"
    );

    // dismiss by pressing Esc
    await triggerKeyEvent(document, "keydown", "Escape");

    assert.ok(query("#dialog-holder"), "element is still in DOM");
    assert.strictEqual(
      query(".dialog-overlay").offsetWidth,
      0,
      "overlay is not visible"
    );
    assert.strictEqual(
      query("#dialog-holder").innerText.trim(),
      "",
      "dialog is empty"
    );
  });

  test("prompt with title", async function (assert) {
    await render(hbs`<DialogHolder />`);

    this.dialog.alert({
      message: "This is a note.",
      title: "And this is a title",
    });

    await settled();

    assert.strictEqual(
      query("#dialog-title").innerText.trim(),
      "And this is a title",
      "dialog has title"
    );

    assert.ok(query(".dialog-close"), "close button present");
    assert.ok(query("#dialog-holder"), "element is still in DOM");
    assert.strictEqual(
      query(".dialog-body").innerText.trim(),
      "This is a note.",
      "dialog message is shown"
    );

    await click(".dialog-close");

    assert.ok(query("#dialog-holder"), "element is still in DOM");
    assert.strictEqual(
      query(".dialog-overlay").offsetWidth,
      0,
      "overlay is not visible"
    );
    assert.strictEqual(
      query("#dialog-holder").innerText.trim(),
      "",
      "dialog is empty"
    );
  });

  test("prompt with a string parameter", async function (assert) {
    await render(hbs`<DialogHolder />`);

    this.dialog.alert("An alert message");
    await settled();

    assert.strictEqual(
      query(".dialog-body").innerText.trim(),
      "An alert message",
      "dialog message is shown"
    );
  });

  test("confirm", async function (assert) {
    let confirmCallbackCalled = false;
    let cancelCallbackCalled = false;
    await render(hbs`<DialogHolder />`);

    this.dialog.confirm({
      message: "A confirm message",
      didConfirm: () => {
        confirmCallbackCalled = true;
      },
    });
    await settled();

    assert.strictEqual(
      query(".dialog-body").innerText.trim(),
      "A confirm message",
      "dialog message is shown"
    );

    assert.strictEqual(
      query(".dialog-footer .btn-primary").innerText.trim(),
      I18n.t("ok_value"),
      "dialog primary button says Ok"
    );

    assert.strictEqual(
      query(".dialog-footer .btn-default").innerText.trim(),
      I18n.t("cancel_value"),
      "dialog second button is present and says No"
    );

    await click(".dialog-footer .btn-primary");

    assert.ok(confirmCallbackCalled);
    assert.notOk(cancelCallbackCalled);
    assert.strictEqual(
      query("#dialog-holder").innerText.trim(),
      "",
      "dialog is empty"
    );
  });

  test("cancel callback", async function (assert) {
    let confirmCallbackCalled = false;
    let cancelCallbackCalled = false;

    await render(hbs`<DialogHolder />`);

    this.dialog.confirm({
      message: "A confirm message",
      didConfirm: () => {
        confirmCallbackCalled = true;
      },
      didCancel: () => {
        cancelCallbackCalled = true;
      },
    });
    await settled();

    assert.strictEqual(
      query(".dialog-body").innerText.trim(),
      "A confirm message",
      "dialog message is shown"
    );

    await click(".dialog-footer .btn-default");
    assert.notOk(confirmCallbackCalled, "confirm callback NOT called");
    assert.ok(cancelCallbackCalled, "cancel callback called");

    assert.strictEqual(
      query("#dialog-holder").innerText.trim(),
      "",
      "dialog has been dismissed"
    );
  });

  test("yes/no confirm", async function (assert) {
    await render(hbs`<DialogHolder />`);

    this.dialog.yesNoConfirm({ message: "A yes/no confirm message" });
    await settled();

    assert.strictEqual(
      query(".dialog-body").innerText.trim(),
      "A yes/no confirm message",
      "dialog message is shown"
    );

    assert.strictEqual(
      query(".dialog-footer .btn-primary").innerText.trim(),
      I18n.t("yes_value"),
      "dialog primary button says Yes"
    );

    assert.strictEqual(
      query(".dialog-footer .btn-default").innerText.trim(),
      I18n.t("no_value"),
      "dialog second button is present and says No"
    );
  });
});
