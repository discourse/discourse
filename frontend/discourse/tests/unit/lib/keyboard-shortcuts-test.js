import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import DiscourseURL from "discourse/lib/url";

module("Unit | Utility | keyboard-shortcuts", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    sinon.stub(DiscourseURL, "routeTo");
  });

  test("goBack calls history.back", function (assert) {
    let called = false;
    sinon.stub(history, "back").callsFake(function () {
      called = true;
    });

    const keyboardShortcuts = this.owner.lookup("service:keyboard-shortcuts");
    keyboardShortcuts.goBack();
    assert.true(called, "history.back is called");
  });

  test("nextSection calls _changeSection with 1", function (assert) {
    const keyboardShortcuts = this.owner.lookup("service:keyboard-shortcuts");
    let spy = sinon.spy(keyboardShortcuts, "_changeSection");

    keyboardShortcuts.nextSection();
    assert.true(spy.calledWith(1), "_changeSection is called with 1");
  });

  test("prevSection calls _changeSection with -1", function (assert) {
    const keyboardShortcuts = this.owner.lookup("service:keyboard-shortcuts");
    let spy = sinon.spy(keyboardShortcuts, "_changeSection");

    keyboardShortcuts.prevSection();
    assert.true(spy.calledWith(-1), "_changeSection is called with -1");
  });
});
