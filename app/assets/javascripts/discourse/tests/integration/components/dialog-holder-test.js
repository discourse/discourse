import {
  click,
  fillIn,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import GroupDeleteDialogMessage from "discourse/components/dialog-messages/group-delete";
import SecondFactorConfirmPhrase from "discourse/components/dialog-messages/second-factor-confirm-phrase";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

module("Integration | Component | dialog-holder", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.dialog = this.container.lookup("service:dialog");
  });

  test("basics", async function (assert) {
    await render(hbs`<DialogHolder />`);
    assert.ok(query("#dialog-holder"), "element is in DOM");
    assert.dom("#dialog-holder").hasText("", "dialog is empty by default");

    this.dialog.alert({
      message: "This is an error",
    });
    await settled();

    assert.true(query(".dialog-overlay").offsetWidth > 0, "overlay is visible");
    assert
      .dom(".dialog-body")
      .hasText("This is an error", "dialog has error message");

    // dismiss by clicking on overlay
    await click(".dialog-overlay");

    assert.ok(query("#dialog-holder"), "element is still in DOM");
    assert.strictEqual(
      query(".dialog-overlay").offsetWidth,
      0,
      "overlay is not visible"
    );
    assert.dom("#dialog-holder").hasText("", "dialog is empty");
  });

  test("basics - dismiss using Esc", async function (assert) {
    let cancelCallbackCalled = false;
    await render(hbs`<DialogHolder />`);
    assert.ok(query("#dialog-holder"), "element is in DOM");
    assert.dom("#dialog-holder").hasText("", "dialog is empty by default");

    this.dialog.alert({
      message: "This is an error",
      didCancel: () => {
        cancelCallbackCalled = true;
      },
    });
    await settled();

    assert.true(query(".dialog-overlay").offsetWidth > 0, "overlay is visible");
    assert
      .dom(".dialog-body")
      .hasText("This is an error", "dialog has error message");

    // dismiss by pressing Esc
    await triggerKeyEvent(document.activeElement, "keydown", "Escape");

    assert.ok(cancelCallbackCalled, "cancel callback called");
    assert.ok(query("#dialog-holder"), "element is still in DOM");

    assert.strictEqual(
      query(".dialog-overlay").offsetWidth,
      0,
      "overlay is not visible"
    );

    assert.dom("#dialog-holder").hasText("", "dialog is empty");
  });

  test("alert with title", async function (assert) {
    await render(hbs`<DialogHolder />`);

    this.dialog.alert({
      message: "This is a note.",
      title: "And this is a title",
    });

    await settled();

    assert
      .dom("#dialog-title")
      .hasText("And this is a title", "dialog has title");

    assert.ok(
      query("#dialog-holder[aria-labelledby='dialog-title']"),
      "aria-labelledby is correctly set"
    );

    assert.ok(query(".dialog-close"), "close button present");
    assert.ok(query("#dialog-holder"), "element is still in DOM");
    assert
      .dom(".dialog-body")
      .hasText("This is a note.", "dialog message is shown");

    await click(".dialog-close");

    assert.ok(query("#dialog-holder"), "element is still in DOM");
    assert.strictEqual(
      query(".dialog-overlay").offsetWidth,
      0,
      "overlay is not visible"
    );
    assert.dom("#dialog-holder").hasText("", "dialog is empty");
  });

  test("alert with a string parameter", async function (assert) {
    await render(hbs`<DialogHolder />`);

    this.dialog.alert("An alert message");
    await settled();

    assert
      .dom(".dialog-body")
      .hasText("An alert message", "dialog message is shown");
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

    assert
      .dom(".dialog-body")
      .hasText("A confirm message", "dialog message is shown");

    assert
      .dom(".dialog-footer .btn-primary")
      .hasText(I18n.t("ok_value"), "dialog primary button says Ok");

    assert
      .dom(".dialog-footer .btn-default")
      .hasText(
        I18n.t("cancel_value"),
        "dialog second button is present and says No"
      );

    await click(".dialog-footer .btn-primary");

    assert.ok(confirmCallbackCalled, "confirm callback called");
    assert.notOk(cancelCallbackCalled, "cancel callback NOT called");

    assert.dom("#dialog-holder").hasText("", "dialog is empty");
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

    assert
      .dom(".dialog-body")
      .hasText("A confirm message", "dialog message is shown");

    await click(".dialog-footer .btn-default");
    assert.notOk(confirmCallbackCalled, "confirm callback NOT called");
    assert.ok(cancelCallbackCalled, "cancel callback called");

    assert.dom("#dialog-holder").hasText("", "dialog has been dismissed");
  });

  test("yes/no confirm", async function (assert) {
    await render(hbs`<DialogHolder />`);

    this.dialog.yesNoConfirm({ message: "A yes/no confirm message" });
    await settled();

    assert
      .dom(".dialog-body")
      .hasText("A yes/no confirm message", "dialog message is shown");

    assert
      .dom(".dialog-footer .btn-primary")
      .hasText(I18n.t("yes_value"), "dialog primary button says Yes");

    assert
      .dom(".dialog-footer .btn-default")
      .hasText(
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
          icon: "gear",
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

    assert
      .dom(".dialog-body")
      .hasText("An alert with custom buttons", "dialog message is shown");

    assert
      .dom(".dialog-footer .btn-danger")
      .hasText("Danger ahead", "dialog custom button is present");

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

    assert.dom("#dialog-holder").hasText("", "dialog has been dismissed");
  });

  test("alert with custom classes", async function (assert) {
    await render(hbs`<DialogHolder />`);

    this.dialog.alert({
      message: "An alert with custom classes",
      class: "dialog-special dialog-super",
    });
    await settled();

    assert
      .dom(".dialog-body")
      .hasText("An alert with custom classes", "dialog message is shown");

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

    assert.dom(".dialog-body").hasText("Noted!", "message is shown");

    assert.notOk(query(".dialog-footer"), "no footer");
    assert.notOk(query(".dialog-header"), "no header");
  });

  test("delete confirm", async function (assert) {
    await render(hbs`<DialogHolder />`);

    this.dialog.deleteConfirm({ message: "A delete confirm message" });
    await settled();

    assert
      .dom(".dialog-body")
      .hasText("A delete confirm message", "dialog message is shown");

    assert
      .dom(".dialog-footer .btn-danger")
      .hasText(
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
      bodyComponent: SecondFactorConfirmPhrase,
      confirmButtonDisabled: true,
    });
    await settled();

    assert.dom(".btn-danger").isDisabled();
    await fillIn("#confirm-phrase", "Disa");
    assert.dom(".btn-danger").isDisabled();
    await fillIn("#confirm-phrase", "Disable");
    assert.dom(".btn-danger").isEnabled();
  });

  test("delete confirm with a component and model", async function (assert) {
    await render(hbs`<DialogHolder />`);
    const message_count = 5;

    this.dialog.deleteConfirm({
      bodyComponent: GroupDeleteDialogMessage,
      bodyComponentModel: {
        message_count,
      },
    });
    await settled();

    assert.dom(".dialog-body p:first-child").hasText(
      I18n.t("admin.groups.delete_with_messages_confirm", {
        count: message_count,
      }),
      "correct message is shown in dialog"
    );
  });
});
