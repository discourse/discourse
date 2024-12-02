import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import getURL, {
  getAbsoluteURL,
  getURLWithCDN,
  isAbsoluteURL,
  setPrefix,
  setupS3CDN,
  setupURL,
  withoutPrefix,
} from "discourse-common/lib/get-url";

module("Unit | Utility | get-url", function (hooks) {
  setupTest(hooks);

  test("isAbsoluteURL", function (assert) {
    setupURL(null, "https://example.com", "/forum");
    assert.true(isAbsoluteURL("https://example.com/test/thing"));
    assert.false(isAbsoluteURL("http://example.com/test/thing"));
    assert.false(isAbsoluteURL("https://discourse.org/test/thing"));
  });

  test("getAbsoluteURL", function (assert) {
    setupURL(null, "https://example.com", null);
    assert.strictEqual(
      getAbsoluteURL("/cool/path"),
      "https://example.com/cool/path"
    );
    setupURL(null, "https://example.com/forum", "/forum");
    assert.strictEqual(
      getAbsoluteURL("/cool/path"),
      "https://example.com/forum/cool/path"
    );
    assert.strictEqual(
      getAbsoluteURL("/forum/cool/path"),
      "https://example.com/forum/cool/path"
    );
  });

  test("withoutPrefix", function (assert) {
    setPrefix("/eviltrout");
    assert.strictEqual(withoutPrefix("/eviltrout/hello"), "/hello");
    assert.strictEqual(withoutPrefix("/eviltrout/"), "/");
    assert.strictEqual(withoutPrefix("/eviltrout"), "");

    setPrefix("");
    assert.strictEqual(withoutPrefix("/eviltrout/hello"), "/eviltrout/hello");
    assert.strictEqual(withoutPrefix("/eviltrout"), "/eviltrout");
    assert.strictEqual(withoutPrefix("/"), "/");

    setPrefix(null);
    assert.strictEqual(withoutPrefix("/eviltrout/hello"), "/eviltrout/hello");
    assert.strictEqual(withoutPrefix("/eviltrout"), "/eviltrout");
    assert.strictEqual(withoutPrefix("/"), "/");

    setPrefix("/f");
    assert.strictEqual(withoutPrefix("/faq"), "/faq");
    assert.strictEqual(withoutPrefix("/f/faq"), "/faq");
    assert.strictEqual(withoutPrefix("/f"), "");
  });

  test("withoutPrefix called multiple times on the same path", function (assert) {
    setPrefix("/eviltrout");
    assert.strictEqual(
      withoutPrefix(withoutPrefix("/eviltrout/hello")),
      "/hello"
    );
    assert.strictEqual(withoutPrefix(withoutPrefix("/eviltrout/")), "/");
    assert.strictEqual(withoutPrefix(withoutPrefix("/eviltrout")), "");

    setPrefix("");
    assert.strictEqual(
      withoutPrefix(withoutPrefix("/eviltrout/hello")),
      "/eviltrout/hello"
    );
    assert.strictEqual(
      withoutPrefix(withoutPrefix("/eviltrout")),
      "/eviltrout"
    );
    assert.strictEqual(withoutPrefix(withoutPrefix("/")), "/");

    setPrefix(null);
    assert.strictEqual(
      withoutPrefix(withoutPrefix("/eviltrout/hello")),
      "/eviltrout/hello"
    );
    assert.strictEqual(
      withoutPrefix(withoutPrefix("/eviltrout")),
      "/eviltrout"
    );
    assert.strictEqual(withoutPrefix(withoutPrefix("/")), "/");

    setPrefix("/f");
    assert.strictEqual(
      withoutPrefix(withoutPrefix("/f/t/falco-says-hello")),
      "/t/falco-says-hello"
    );
    assert.strictEqual(
      withoutPrefix(withoutPrefix("/f/tag/fast-chain-food")),
      "/tag/fast-chain-food"
    );
    assert.strictEqual(
      withoutPrefix(withoutPrefix("/f/u/falco/summary")),
      "/u/falco/summary"
    );
  });

  test("getURL with empty paths", function (assert) {
    setupURL(null, "https://example.com", "/");
    assert.strictEqual(getURL("/"), "/");
    assert.strictEqual(getURL(""), "");
    setupURL(null, "https://example.com", "");
    assert.strictEqual(getURL("/"), "/");
    assert.strictEqual(getURL(""), "");
    setupURL(null, "https://example.com", undefined);
    assert.strictEqual(getURL("/"), "/");
    assert.strictEqual(getURL(""), "");
  });

  test("getURL on subfolder install", function (assert) {
    setupURL(null, "", "/forum");
    assert.strictEqual(getURL("/"), "/forum/", "root url has subfolder");
    assert.strictEqual(
      getURL("/u/neil"),
      "/forum/u/neil",
      "relative url has subfolder"
    );

    assert.strictEqual(
      getURL("/u/forumadmin"),
      "/forum/u/forumadmin",
      "relative url has subfolder even if username contains subfolder"
    );

    assert.strictEqual(
      getURL(""),
      "/forum",
      "relative url has subfolder without trailing slash"
    );

    assert.strictEqual(
      getURL("/svg-sprite/forum.example.com/svg-sprite.js"),
      "/forum/svg-sprite/forum.example.com/svg-sprite.js",
      "works when the url has the prefix in the middle"
    );

    assert.strictEqual(
      getURL("/forum/t/123"),
      "/forum/t/123",
      "does not prefix if the URL is already prefixed"
    );

    setPrefix("/f");
    assert.strictEqual(
      getURL("/faq"),
      "/f/faq",
      "relative path has subfolder even if it starts with the prefix without trailing slash"
    );
    assert.strictEqual(
      getURL("/f/faq"),
      "/f/faq",
      "does not prefix if the URL is already prefixed"
    );
  });

  test("getURLWithCDN on subfolder install with S3", function (assert) {
    setupURL(null, "", "/forum");
    setupS3CDN(
      "//test.s3-us-west-1.amazonaws.com/site",
      "https://awesome.cdn/site"
    );

    let url = "//test.s3-us-west-1.amazonaws.com/site/forum/awesome.png";
    let expected = "https://awesome.cdn/site/forum/awesome.png";

    assert.strictEqual(getURLWithCDN(url), expected, "at correct path");
  });

  test("getURLWithCDN when URL includes protocol", function (assert) {
    setupS3CDN("//awesome.cdn/site", "https://awesome.cdn/site");

    let url = "https://awesome.cdn/site/awesome.png";

    assert.strictEqual(getURLWithCDN(url), url, "at correct path");
  });
});
