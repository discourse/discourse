import {
  acceptance,
  count,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { click, settled, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import I18n from "I18n";
import { hbs } from "ember-cli-htmlbars";
import showModal from "discourse/lib/show-modal";
import { registerTemporaryModule } from "../helpers/temporary-module-helper";
import { getOwner } from "discourse-common/lib/get-owner";
import { withSilencedDeprecations } from "discourse-common/lib/deprecated";
import Component from "@glimmer/component";
import { setComponentTemplate } from "@glimmer/manager";

function silencedShowModal() {
  return withSilencedDeprecations("discourse.modal-controllers", () =>
    showModal(...arguments)
  );
}

acceptance("Legacy Modal", function (needs) {
  let _translations;
  needs.hooks.beforeEach(() => {
    _translations = I18n.translations;

    I18n.translations = {
      en: {
        js: {
          test_title: "Test title",
        },
      },
    };
  });

  needs.hooks.afterEach(() => {
    I18n.translations = _translations;
  });

  test("modal", async function (assert) {
    await visit("/");

    assert.ok(!exists(".d-modal:visible"), "there is no modal at first");

    await click(".login-button");
    assert.strictEqual(count(".d-modal:visible"), 1, "modal should appear");

    const service = getOwner(this).lookup("service:modal");
    assert.strictEqual(service.name, "login");

    await click(".modal-outer-container");
    assert.ok(
      !exists(".d-modal:visible"),
      "modal should disappear when you click outside"
    );
    assert.strictEqual(service.name, null);

    await click(".login-button");
    assert.strictEqual(count(".d-modal:visible"), 1, "modal should reappear");

    await triggerKeyEvent("#main-outlet", "keydown", "Escape");
    assert.ok(!exists(".d-modal:visible"), "ESC should close the modal");

    registerTemporaryModule(
      "discourse/templates/modal/not-dismissable",
      hbs`{{#d-modal-body title="" class="" dismissable=false}}test{{/d-modal-body}}`
    );

    silencedShowModal("not-dismissable", {});
    await settled();

    assert.strictEqual(count(".d-modal:visible"), 1, "modal should appear");

    await click(".modal-outer-container");
    assert.strictEqual(
      count(".d-modal:visible"),
      1,
      "modal should not disappear when you click outside"
    );
    await triggerKeyEvent("#main-outlet", "keyup", "Escape");
    assert.strictEqual(
      count(".d-modal:visible"),
      1,
      "ESC should not close the modal"
    );
  });

  test("rawTitle in modal panels", async function (assert) {
    registerTemporaryModule(
      "discourse/templates/modal/test-raw-title-panels",
      hbs``
    );
    const panels = [
      { id: "test1", rawTitle: "Test 1" },
      { id: "test2", rawTitle: "Test 2" },
    ];

    await visit("/");
    silencedShowModal("test-raw-title-panels", { panels });
    await settled();

    assert.strictEqual(
      query(".d-modal .modal-tab:first-child").innerText.trim(),
      "Test 1",
      "it should display the raw title"
    );
  });

  test("modal title", async function (assert) {
    registerTemporaryModule("discourse/templates/modal/test-title", hbs``);
    registerTemporaryModule(
      "discourse/templates/modal/test-title-with-body",
      hbs`{{#d-modal-body}}test{{/d-modal-body}}`
    );

    await visit("/");

    silencedShowModal("test-title", { title: "test_title" });
    await settled();
    assert.strictEqual(
      query(".d-modal .title").innerText.trim(),
      "Test title",
      "it should display the title"
    );

    await click(".d-modal .close");

    silencedShowModal("test-title-with-body", { title: "test_title" });
    await settled();
    assert.strictEqual(
      query(".d-modal .title").innerText.trim(),
      "Test title",
      "it should display the title when used with d-modal-body"
    );

    await click(".d-modal .close");

    silencedShowModal("test-title");
    await settled();
    assert.ok(
      !exists(".d-modal .title"),
      "it should not re-use the previous title"
    );
  });

  test("opening legacy modal while modern modal is open", async function (assert) {
    registerTemporaryModule(
      "discourse/templates/modal/legacy-modal",
      hbs`<DModalBody @rawTitle="legacy modal title" />`
    );

    class ModernModal extends Component {}
    setComponentTemplate(
      hbs`<DModal @title="modern modal title" />`,
      ModernModal
    );

    await visit("/");

    const modalService = getOwner(this).lookup("service:modal");

    modalService.show(ModernModal);
    await settled();
    assert.dom(".d-modal .title").hasText("modern modal title");

    silencedShowModal("legacy-modal");
    await settled();

    assert.dom(".d-modal .title").hasText("legacy modal title");
  });
});

acceptance("Modal Keyboard Events", function (needs) {
  needs.user();

  test("modal-keyboard-events", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");
    await triggerKeyEvent(".d-modal", "keydown", "Enter");

    assert.strictEqual(
      count("#modal-alert:visible"),
      1,
      "hitting Enter triggers modal action"
    );
    assert.strictEqual(
      count(".d-modal:visible"),
      1,
      "hitting Enter does not dismiss modal due to alert error"
    );

    assert.ok(exists(".d-modal:visible"), "modal should be visible");

    await triggerKeyEvent("#main-outlet", "keydown", "Escape");

    assert.ok(!exists(".d-modal:visible"), "ESC should close the modal");

    await click(".topic-body button.reply");
    await click(".d-editor-button-bar .btn.link");
    await triggerKeyEvent(".d-modal", "keydown", "Enter");

    assert.ok(
      !exists(".d-modal:visible"),
      "modal should disappear on hitting Enter"
    );
  });
});
