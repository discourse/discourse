import I18n from "I18n";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  click,
  fillIn,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
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
    let cancelCallbackCalled = false;
    await render(hbs`<DialogHolder />`);
    assert.ok(query("#dialog-holder"), "element is in DOM");
    assert.strictEqual(
      query("#dialog-holder").innerText.trim(),
      "",
      "dialog is empty by default"
    );

    this.dialog.alert({
      message: "This is an error",
      didCancel: () => {
        cancelCallbackCalled = true;
      },
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

    assert.ok(cancelCallbackCalled, "cancel callback called");
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

  test("alert with title", async function (assert) {
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

    assert.ok(
      query("#dialog-holder[aria-labelledby='dialog-title']"),
      "aria-labelledby is correctly set"
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

  test("alert with a string parameter", async function (assert) {
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

    assert.ok(confirmCallbackCalled, "confirm callback called");
    assert.notOk(cancelCallbackCalled, "cancel callback NOT called");

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

  test("alert with custom buttons", async function (assert) {
    let customCallbackTriggered = false;
    await render(hbs`<DialogHolder />`);

    this.dialog.alert({
      message: "An alert with custom buttons",
      buttons: [
        {
          icon: "cog",
          label: "Danger ahead",
          class: "btn-danger",
          action: () => {
            return new Promise((resolve) => {
              customCallbackTriggered = true;
              return resolve();
            });
          },
        },
      ],
    });
    await settled();

    assert.strictEqual(
      query(".dialog-body").innerText.trim(),
      "An alert with custom buttons",
      "dialog message is shown"
    );

    assert.strictEqual(
      query(".dialog-footer .btn-danger").innerText.trim(),
      "Danger ahead",
      "dialog custom button is present"
    );

    assert.notOk(
      query(".dialog-footer .btn-primary"),
      "default confirm button is not present"
    );
    assert.notOk(
      query(".dialog-footer .btn-default"),
      "default cancel button is not present"
    );

    await click(".dialog-footer .btn-danger");
    assert.ok(customCallbackTriggered, "custom action was triggered");

    assert.strictEqual(
      query("#dialog-holder").innerText.trim(),
      "",
      "dialog has been dismissed"
    );
  });

  test("alert with custom classes", async function (assert) {
    await render(hbs`<DialogHolder />`);

    this.dialog.alert({
      message: "An alert with custom classes",
      class: "dialog-special dialog-super",
    });
    await settled();

    assert.strictEqual(
      query(".dialog-body").innerText.trim(),
      "An alert with custom classes",
      "dialog message is shown"
    );

    assert.ok(
      query("#dialog-holder.dialog-special.dialog-super"),
      "additional classes are present"
    );

    await click(".dialog-footer .btn-primary");

    assert.notOk(
      query("#dialog-holder.dialog-special"),
      "additional class removed on dismissal"
    );

    assert.notOk(
      query("#dialog-holder.dialog-super"),
      "additional class removed on dismissal"
    );
  });

  test("notice", async function (assert) {
    await render(hbs`<DialogHolder />`);

    this.dialog.notice("Noted!");
    await settled();

    assert.strictEqual(
      query(".dialog-body").innerText.trim(),
      "Noted!",
      "message is shown"
    );

    assert.notOk(query(".dialog-footer"), "no footer");
    assert.notOk(query(".dialog-header"), "no header");
  });

  test("delete confirm", async function (assert) {
    await render(hbs`<DialogHolder />`);

    this.dialog.deleteConfirm({ message: "A delete confirm message" });
    await settled();

    assert.strictEqual(
      query(".dialog-body").innerText.trim(),
      "A delete confirm message",
      "dialog message is shown"
    );

    assert.strictEqual(
      query(".dialog-footer .btn-danger").innerText.trim(),
      I18n.t("delete"),
      "dialog primary button use danger class and label is Delete"
    );

    assert.notOk(
      query(".dialog-footer .btn-primary"),
      ".btn-primary element is not present in the dialog"
    );
  });

  test("delete confirm with confirmation phrase component", async function (assert) {
    await render(hbs`<DialogHolder />`);

    this.dialog.deleteConfirm({
      bodyComponent: "dialog-messages/second-factor-confirm-phrase",
      confirmButtonDisabled: true,
    });
    await settled();

    assert.strictEqual(query(".btn-danger").disabled, true);
    await fillIn("#confirm-phrase", "Disa");
    assert.strictEqual(query(".btn-danger").disabled, true);
    await fillIn("#confirm-phrase", "Disable");
    assert.strictEqual(query(".btn-danger").disabled, false);
  });

  test("delete confirm with a component and model", async function (assert) {
    await render(hbs`<DialogHolder />`);
    const message_count = 5;

    this.dialog.deleteConfirm({
      bodyComponent: "dialog-messages/group-delete",
      bodyComponentModel: {
        message_count,
      },
    });
    await settled();

    assert.strictEqual(
      query(".dialog-body").innerText.trim(),
      I18n.t("admin.groups.delete_with_messages_confirm", {
        count: message_count,
      }),
      "correct message is shown in dialog"
    );
  });
});
