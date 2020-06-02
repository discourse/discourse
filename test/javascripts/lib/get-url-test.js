import {
  default as getURL,
  setupURL,
  setupS3CDN,
  getURLWithCDN,
  isAbsoluteURL,
  getAbsoluteURL,
  setPrefix,
  withoutPrefix
} from "discourse-common/lib/get-url";

QUnit.module("lib:get-url");

QUnit.test("isAbsoluteURL", assert => {
  setupURL(null, "https://example.com", "/forum");
  assert.ok(isAbsoluteURL("https://example.com/test/thing"));
  assert.ok(!isAbsoluteURL("http://example.com/test/thing"));
  assert.ok(!isAbsoluteURL("https://discourse.org/test/thing"));
});

QUnit.test("getAbsoluteURL", assert => {
  setupURL(null, "https://example.com", "/forum");
  assert.equal(getAbsoluteURL("/cool/path"), "https://example.com/cool/path");
});

QUnit.test("withoutPrefix", assert => {
  setPrefix("/eviltrout");
  assert.equal(withoutPrefix("/eviltrout/hello"), "/hello");
  assert.equal(withoutPrefix("/eviltrout/"), "/");
  assert.equal(withoutPrefix("/eviltrout"), "");

  setPrefix("");
  assert.equal(withoutPrefix("/eviltrout/hello"), "/eviltrout/hello");
  assert.equal(withoutPrefix("/eviltrout"), "/eviltrout");
  assert.equal(withoutPrefix("/"), "/");

  setPrefix(null);
  assert.equal(withoutPrefix("/eviltrout/hello"), "/eviltrout/hello");
  assert.equal(withoutPrefix("/eviltrout"), "/eviltrout");
  assert.equal(withoutPrefix("/"), "/");
});

QUnit.test("getURL with empty paths", assert => {
  setupURL(null, "https://example.com", "/");
  assert.equal(getURL("/"), "/");
  assert.equal(getURL(""), "");
  setupURL(null, "https://example.com", "");
  assert.equal(getURL("/"), "/");
  assert.equal(getURL(""), "");
  setupURL(null, "https://example.com", undefined);
  assert.equal(getURL("/"), "/");
  assert.equal(getURL(""), "");
});

QUnit.test("getURL on subfolder install", assert => {
  setupURL(null, "", "/forum");
  assert.equal(getURL("/"), "/forum/", "root url has subfolder");
  assert.equal(
    getURL("/u/neil"),
    "/forum/u/neil",
    "relative url has subfolder"
  );

  assert.equal(
    getURL("/svg-sprite/forum.example.com/svg-sprite.js"),
    "/forum/svg-sprite/forum.example.com/svg-sprite.js",
    "works when the url has the prefix in the middle"
  );

  assert.equal(
    getURL("/forum/t/123"),
    "/forum/t/123",
    "does not prefix if the URL is already prefixed"
  );
});

QUnit.test("getURLWithCDN on subfolder install with S3", assert => {
  setupURL(null, "", "/forum");
  setupS3CDN(
    "//test.s3-us-west-1.amazonaws.com/site",
    "https://awesome.cdn/site"
  );

  let url = "//test.s3-us-west-1.amazonaws.com/site/forum/awesome.png";
  let expected = "https://awesome.cdn/site/forum/awesome.png";

  assert.equal(getURLWithCDN(url), expected, "at correct path");
});
