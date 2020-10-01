import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import { currentUser } from "discourse/tests/helpers/qunit-helpers";

discourseModule("service:document-title", {
  beforeEach() {
    this.documentTitle = this.container.lookup("service:document-title");
    this.documentTitle.currentUser = null;
    this.container.lookup("session:main").hasFocus = true;
  },
  afterEach() {
    this.documentTitle.reset();
  },
});

QUnit.test("it updates the document title", function (assert) {
  this.documentTitle.setTitle("Test Title");
  assert.equal(document.title, "Test Title", "title is correct");
});

QUnit.test(
  "it doesn't display notification counts for anonymous users",
  function (assert) {
    this.documentTitle.setTitle("test notifications");
    this.documentTitle.updateNotificationCount(5);
    assert.equal(document.title, "test notifications");
    this.documentTitle.setFocus(false);
    this.documentTitle.updateNotificationCount(6);
    assert.equal(document.title, "test notifications");
  }
);

QUnit.test("it displays notification counts for logged in users", function (
  assert
) {
  this.documentTitle.currentUser = currentUser();
  this.documentTitle.currentUser.dynamic_favicon = false;
  this.documentTitle.setTitle("test notifications");
  this.documentTitle.updateNotificationCount(5);
  assert.equal(document.title, "test notifications");
  this.documentTitle.setFocus(false);
  this.documentTitle.updateNotificationCount(6);
  assert.equal(document.title, "(6) test notifications");
  this.documentTitle.setFocus(true);
  assert.equal(document.title, "test notifications");
});

QUnit.test(
  "it doesn't increment background context counts when focused",
  function (assert) {
    this.documentTitle.setTitle("background context");
    this.documentTitle.setFocus(true);
    this.documentTitle.incrementBackgroundContextCount();
    assert.equal(document.title, "background context");
  }
);

QUnit.test(
  "it increments background context counts when not focused",
  function (assert) {
    this.documentTitle.setTitle("background context");
    this.documentTitle.setFocus(false);
    this.documentTitle.incrementBackgroundContextCount();
    assert.equal(document.title, "(1) background context");
    this.documentTitle.setFocus(true);
    assert.equal(document.title, "background context");
  }
);
