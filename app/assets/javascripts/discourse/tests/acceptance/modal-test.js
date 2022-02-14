import {
  acceptance,
  controllerFor,
  count,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { click, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import I18n from "I18n";
import hbs from "htmlbars-inline-precompile";
import { run } from "@ember/runloop";
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

    assert.ok(!exists(".d-modal:visible"), "there is no modal at first");

    await click(".login-button");
    assert.strictEqual(count(".d-modal:visible"), 1, "modal should appear");

    let controller = controllerFor("modal");
    assert.strictEqual(controller.name, "login");

    await click(".modal-outer-container");
    assert.ok(
      !exists(".d-modal:visible"),
      "modal should disappear when you click outside"
    );
    assert.strictEqual(controller.name, null);

    await click(".login-button");
    assert.strictEqual(count(".d-modal:visible"), 1, "modal should reappear");

    await triggerKeyEvent("#main-outlet", "keydown", 27);
    assert.ok(!exists(".d-modal:visible"), "ESC should close the modal");

    Ember.TEMPLATES[
      "modal/not-dismissable"
    ] = hbs`{{#d-modal-body title="" class="" dismissable=false}}test{{/d-modal-body}}`;

    run(() => showModal("not-dismissable", {}));

    assert.strictEqual(count(".d-modal:visible"), 1, "modal should appear");

    await click(".modal-outer-container");
    assert.strictEqual(
      count(".d-modal:visible"),
      1,
      "modal should not disappear when you click outside"
    );
    await triggerKeyEvent("#main-outlet", "keyup", 27);
    assert.strictEqual(
      count(".d-modal:visible"),
      1,
      "ESC should not close the modal"
    );
  });

  test("rawTitle in modal panels", async function (assert) {
    Ember.TEMPLATES["modal/test-raw-title-panels"] = hbs``;
    const panels = [
      { id: "test1", rawTitle: "Test 1" },
      { id: "test2", rawTitle: "Test 2" },
    ];

    await visit("/");
    run(() => showModal("test-raw-title-panels", { panels }));

    assert.strictEqual(
      queryAll(".d-modal .modal-tab:first-child").text().trim(),
      "Test 1",
      "it should display the raw title"
    );
  });

  test("modal title", async function (assert) {
    Ember.TEMPLATES["modal/test-title"] = hbs``;
    Ember.TEMPLATES[
      "modal/test-title-with-body"
    ] = hbs`{{#d-modal-body}}test{{/d-modal-body}}`;

    await visit("/");

    run(() => showModal("test-title", { title: "test_title" }));
    assert.strictEqual(
      queryAll(".d-modal .title").text().trim(),
      "Test title",
      "it should display the title"
    );

    await click(".d-modal .close");

    run(() => showModal("test-title-with-body", { title: "test_title" }));
    assert.strictEqual(
      queryAll(".d-modal .title").text().trim(),
      "Test title",
      "it should display the title when used with d-modal-body"
    );

    await click(".d-modal .close");

    run(() => showModal("test-title"));
    assert.ok(
      !exists(".d-modal .title"),
      "it should not re-use the previous title"
    );
  });
});

acceptance("Modal Keyboard Events", function (needs) {
  needs.user();

  test("modal-keyboard-events", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");
    await triggerKeyEvent(".d-modal", "keydown", 13);

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

    await triggerKeyEvent("#main-outlet", "keydown", 27);

    assert.ok(!exists(".d-modal:visible"), "ESC should close the modal");

    await click(".topic-body button.reply");
    await click(".d-editor-button-bar .btn.link");
    await triggerKeyEvent(".d-modal", "keydown", 13);

    assert.ok(
      !exists(".d-modal:visible"),
      "modal should disappear on hitting Enter"
    );
  });
});
