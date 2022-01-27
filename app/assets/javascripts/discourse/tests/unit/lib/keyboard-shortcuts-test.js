import { module, test } from "qunit";
import DiscourseURL from "discourse/lib/url";
import KeyboardShortcuts from "discourse/lib/keyboard-shortcuts";
import sinon from "sinon";

module("Unit | Utility | keyboard-shortcuts", function (hooks) {
  hooks.beforeEach(function () {
    sinon.stub(DiscourseURL, "routeTo");
  });

  test("selectDown calls _moveSelection with 1", function (assert) {
    let stub = sinon.stub(KeyboardShortcuts, "_moveSelection");

    KeyboardShortcuts.selectDown();
    assert.ok(stub.calledWith(1), "_moveSelection is called with 1");
  });

  test("selectUp calls _moveSelection with -1", function (assert) {
    let stub = sinon.stub(KeyboardShortcuts, "_moveSelection");

    KeyboardShortcuts.selectUp();
    assert.ok(stub.calledWith(-1), "_moveSelection is called with -1");
  });

  test("goBack calls history.back", function (assert) {
    let called = false;
    sinon.stub(history, "back").callsFake(function () {
      called = true;
    });

    KeyboardShortcuts.goBack();
    assert.ok(called, "history.back is called");
  });

  test("nextSection calls _changeSection with 1", function (assert) {
    let spy = sinon.spy(KeyboardShortcuts, "_changeSection");

    KeyboardShortcuts.nextSection();
    assert.ok(spy.calledWith(1), "_changeSection is called with 1");
  });

  test("prevSection calls _changeSection with -1", function (assert) {
    let spy = sinon.spy(KeyboardShortcuts, "_changeSection");

    KeyboardShortcuts.prevSection();
    assert.ok(spy.calledWith(-1), "_changeSection is called with -1");
  });
});
