import { acceptance } from "helpers/qunit-helpers";
import showModal from "discourse/lib/show-modal";

acceptance("Modal");

QUnit.test("modal", assert => {
  visit("/");

  andThen(() => {
    assert.ok(
      find(".d-modal:visible").length === 0,
      "there is no modal at first"
    );
  });

  click(".login-button");
  andThen(() => {
    assert.ok(find(".d-modal:visible").length === 1, "modal should appear");
  });

  click(".modal-outer-container");
  andThen(() => {
    assert.ok(
      find(".d-modal:visible").length === 0,
      "modal should disappear when you click outside"
    );
  });

  click(".login-button");
  andThen(() => {
    assert.ok(find(".d-modal:visible").length === 1, "modal should reappear");
  });

  keyEvent("#main-outlet", "keydown", 27);
  andThen(() => {
    assert.ok(
      find(".d-modal:visible").length === 0,
      "ESC should close the modal"
    );
  });
  andThen(() => {
    Ember.TEMPLATES["modal/not-dismissable"] = Ember.HTMLBars.compile(
      '{{#d-modal-body title="" class="" dismissable=false}}test{{/d-modal-body}}'
    );
    showModal("not-dismissable", {});
  });
  andThen(() => {
    assert.ok(find(".d-modal:visible").length === 1, "modal should appear");
  });
  click(".modal-outer-container");
  andThen(() => {
    assert.ok(
      find(".d-modal:visible").length === 1,
      "modal should not disappear when you click outside"
    );
  });
  keyEvent("#main-outlet", "keydown", 27);
  andThen(() => {
    assert.ok(
      find(".d-modal:visible").length === 1,
      "ESC should not close the modal"
    );
  });
});
