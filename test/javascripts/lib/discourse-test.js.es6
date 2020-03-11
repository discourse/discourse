import { logIn, updateCurrentUser } from "helpers/qunit-helpers";

QUnit.module("lib:discourse");

QUnit.test("getURL on subfolder install", assert => {
  Discourse.BaseUri = "/forum";
  assert.equal(Discourse.getURL("/"), "/forum/", "root url has subfolder");
  assert.equal(
    Discourse.getURL("/u/neil"),
    "/forum/u/neil",
    "relative url has subfolder"
  );

  assert.equal(
    Discourse.getURL("/svg-sprite/forum.example.com/svg-sprite.js"),
    "/forum/svg-sprite/forum.example.com/svg-sprite.js",
    "works when the url has the prefix in the middle"
  );

  assert.equal(
    Discourse.getURL("/forum/t/123"),
    "/forum/t/123",
    "does not prefix if the URL is already prefixed"
  );
});

QUnit.test("getURLWithCDN on subfolder install with S3", assert => {
  Discourse.BaseUri = "/forum";

  Discourse.S3CDN = "https://awesome.cdn/site";
  Discourse.S3BaseUrl = "//test.s3-us-west-1.amazonaws.com/site";

  let url = "//test.s3-us-west-1.amazonaws.com/site/forum/awesome.png";
  let expected = "https://awesome.cdn/site/forum/awesome.png";

  assert.equal(Discourse.getURLWithCDN(url), expected, "at correct path");

  Discourse.S3CDN = null;
  Discourse.S3BaseUrl = null;
});

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
