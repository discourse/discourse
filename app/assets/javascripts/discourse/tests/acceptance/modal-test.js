import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import I18n from "I18n";
import { run } from "@ember/runloop";
import {
  acceptance,
  controllerFor,
} from "discourse/tests/helpers/qunit-helpers";
import showModal from "discourse/lib/show-modal";

acceptance("Modal", function (needs) {
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

    assert.ok(
      find(".d-modal:visible").length === 0,
      "there is no modal at first"
    );

    await click(".login-button");
    assert.ok(find(".d-modal:visible").length === 1, "modal should appear");

    let controller = controllerFor("modal");
    assert.equal(controller.name, "login");

    await click(".modal-outer-container");
    assert.ok(
      find(".d-modal:visible").length === 0,
      "modal should disappear when you click outside"
    );
    assert.equal(controller.name, null);

    await click(".login-button");
    assert.ok(find(".d-modal:visible").length === 1, "modal should reappear");

    await keyEvent("#main-outlet", "keyup", 27);
    assert.ok(
      find(".d-modal:visible").length === 0,
      "ESC should close the modal"
    );

    Ember.TEMPLATES["modal/not-dismissable"] = Ember.HTMLBars.compile(
      '{{#d-modal-body title="" class="" dismissable=false}}test{{/d-modal-body}}'
    );

    run(() => showModal("not-dismissable", {}));

    assert.ok(find(".d-modal:visible").length === 1, "modal should appear");

    await click(".modal-outer-container");
    assert.ok(
      find(".d-modal:visible").length === 1,
      "modal should not disappear when you click outside"
    );
    await keyEvent("#main-outlet", "keyup", 27);
    assert.ok(
      find(".d-modal:visible").length === 1,
      "ESC should not close the modal"
    );
  });

  test("rawTitle in modal panels", async function (assert) {
    Ember.TEMPLATES["modal/test-raw-title-panels"] = Ember.HTMLBars.compile("");
    const panels = [
      { id: "test1", rawTitle: "Test 1" },
      { id: "test2", rawTitle: "Test 2" },
    ];

    await visit("/");
    run(() => showModal("test-raw-title-panels", { panels }));

    assert.equal(
      find(".d-modal .modal-tab:first-child").text().trim(),
      "Test 1",
      "it should display the raw title"
    );
  });

  test("modal title", async function (assert) {
    Ember.TEMPLATES["modal/test-title"] = Ember.HTMLBars.compile("");
    Ember.TEMPLATES["modal/test-title-with-body"] = Ember.HTMLBars.compile(
      "{{#d-modal-body}}test{{/d-modal-body}}"
    );

    await visit("/");

    run(() => showModal("test-title", { title: "test_title" }));
    assert.equal(
      find(".d-modal .title").text().trim(),
      "Test title",
      "it should display the title"
    );

    await click(".d-modal .close");

    run(() => showModal("test-title-with-body", { title: "test_title" }));
    assert.equal(
      find(".d-modal .title").text().trim(),
      "Test title",
      "it should display the title when used with d-modal-body"
    );

    await click(".d-modal .close");

    run(() => showModal("test-title"));
    assert.ok(
      find(".d-modal .title").length === 0,
      "it should not re-use the previous title"
    );
  });
});

acceptance("Modal Keyboard Events", function (needs) {
  needs.user();

  test("modal-keyboard-events", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(".toggle-admin-menu");
    await click(".topic-admin-status-update button");
    await keyEvent(".d-modal", "keyup", 13);

    assert.ok(
      find("#modal-alert:visible").length === 1,
      "hitting Enter triggers modal action"
    );
    assert.ok(
      find(".d-modal:visible").length === 1,
      "hitting Enter does not dismiss modal due to alert error"
    );

    await keyEvent("#main-outlet", "keyup", 27);
    assert.ok(
      find(".d-modal:visible").length === 0,
      "ESC should close the modal"
    );

    await click(".topic-body button.reply");

    await click(".d-editor-button-bar .btn.link");

    await keyEvent(".d-modal", "keyup", 13);
    assert.ok(
      find(".d-modal:visible").length === 0,
      "modal should disappear on hitting Enter"
    );
  });
});
