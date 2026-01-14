import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { logIn } from "discourse/tests/helpers/qunit-helpers";

module("Unit | Service | document-title", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    const session = getOwner(this).lookup("service:session");
    session.hasFocus = true;

    this.documentTitle = getOwner(this).lookup("service:document-title");
  });

  test("it updates the document title", function (assert) {
    this.documentTitle.setTitle("Test Title");
    assert.strictEqual(document.title, "Test Title", "title is correct");
  });

  test("it doesn't display notification counts for anonymous users", function (assert) {
    this.documentTitle.setTitle("test notifications");
    this.documentTitle.updateNotificationCount(5);
    assert.strictEqual(document.title, "test notifications");
    this.documentTitle.setFocus(false);
    this.documentTitle.updateNotificationCount(6);
    assert.strictEqual(document.title, "test notifications");
  });

  test("it displays notification counts for logged in users", function (assert) {
    const currentUser = logIn(this.owner);
    currentUser.user_option.dynamic_favicon = false;

    this.documentTitle.setTitle("test notifications");
    this.documentTitle.updateNotificationCount(5);
    assert.strictEqual(document.title, "test notifications");
    this.documentTitle.setFocus(false);
    this.documentTitle.updateNotificationCount(6);
    assert.strictEqual(document.title, "(6) test notifications");
    this.documentTitle.setFocus(true);
    assert.strictEqual(document.title, "test notifications");
  });

  test("it doesn't display notification counts for users in do not disturb", function (assert) {
    const currentUser = logIn(this.owner);

    const date = new Date();
    date.setHours(date.getHours() + 1);
    currentUser.do_not_disturb_until = date.toUTCString();

    currentUser.user_option.dynamic_favicon = false;
    this.documentTitle.setTitle("test notifications");
    this.documentTitle.updateNotificationCount(5);
    assert.strictEqual(document.title, "test notifications");
    this.documentTitle.setFocus(false);
    this.documentTitle.updateNotificationCount(6);
    assert.strictEqual(document.title, "test notifications");
  });

  test("it doesn't increment background context counts when focused", function (assert) {
    this.documentTitle.setTitle("background context");
    this.documentTitle.setFocus(true);
    this.documentTitle.incrementBackgroundContextCount();
    assert.strictEqual(document.title, "background context");
  });

  test("it increments background context counts when not focused", function (assert) {
    this.documentTitle.setTitle("background context");
    this.documentTitle.setFocus(false);
    this.documentTitle.incrementBackgroundContextCount();
    assert.strictEqual(document.title, "(1) background context");
    this.documentTitle.setFocus(true);
    assert.strictEqual(document.title, "background context");
  });
});
