import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";

module("Unit | Controller | login", function (hooks) {
  setupTest(hooks);

  test("setFlash announces a message that is already shown", function (assert) {
    const controller = this.owner.lookup("controller:login");
    const announce = sinon.stub(this.owner.lookup("service:a11y"), "announce");

    controller.setFlash("Incorrect password");
    assert.false(
      announce.called,
      "a new message is announced by the flash message itself"
    );

    controller.setFlash("Incorrect password");
    assert.true(
      announce.calledOnceWithExactly("Incorrect password", "assertive"),
      "the same message again is announced, since the page does not change"
    );

    controller.setFlash("Too many attempts");
    assert.true(
      announce.calledOnce,
      "a different message is not announced twice"
    );
  });
});
