import { acceptance, controllerFor } from "helpers/qunit-helpers";
import showModal from "discourse/lib/show-modal";

acceptance("Modal");

QUnit.test("modal", async function(assert) {
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

  await keyEvent("#main-outlet", "keydown", 27);
  assert.ok(
    find(".d-modal:visible").length === 0,
    "ESC should close the modal"
  );

  Ember.TEMPLATES["modal/not-dismissable"] = Ember.HTMLBars.compile(
    '{{#d-modal-body title="" class="" dismissable=false}}test{{/d-modal-body}}'
  );

  Ember.run(() => showModal("not-dismissable", {}));

  assert.ok(find(".d-modal:visible").length === 1, "modal should appear");

  await click(".modal-outer-container");
  assert.ok(
    find(".d-modal:visible").length === 1,
    "modal should not disappear when you click outside"
  );
  await keyEvent("#main-outlet", "keydown", 27);
  assert.ok(
    find(".d-modal:visible").length === 1,
    "ESC should not close the modal"
  );
});
