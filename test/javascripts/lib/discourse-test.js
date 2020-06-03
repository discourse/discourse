import { logIn, updateCurrentUser } from "helpers/qunit-helpers";

QUnit.module("lib:discourse");

QUnit.test("title counts are updated correctly", assert => {
  Discourse.set("hasFocus", true);
  Discourse.set("contextCount", 0);
  Discourse.set("notificationCount", 0);

  Discourse.set("_docTitle", "Test Title");

  assert.equal(document.title, "Test Title", "title is correct");

  Discourse.updateNotificationCount(5);
  assert.equal(document.title, "Test Title", "title doesn't change with focus");

  Discourse.incrementBackgroundContextCount();
  assert.equal(document.title, "Test Title", "title doesn't change with focus");

  Discourse.set("hasFocus", false);

  Discourse.updateNotificationCount(5);
  assert.equal(
    document.title,
    "Test Title",
    "notification count ignored for anon"
  );

  Discourse.incrementBackgroundContextCount();
  assert.equal(
    document.title,
    "(1) Test Title",
    "title changes when incremented for anon"
  );

  logIn();
  updateCurrentUser({ dynamic_favicon: false });

  Discourse.set("hasFocus", true);
  Discourse.set("hasFocus", false);

  Discourse.incrementBackgroundContextCount();
  assert.equal(
    document.title,
    "Test Title",
    "title doesn't change when incremented for logged in"
  );

  Discourse.updateNotificationCount(3);
  assert.equal(
    document.title,
    "(3) Test Title",
    "title includes notification count for logged in user"
  );

  Discourse.set("hasFocus", false);
  Discourse.set("hasFocus", true);

  assert.equal(
    document.title,
    "Test Title",
    "counter dissappears after focus, and doesn't reappear until another notification arrives"
  );
});
