import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import DiscourseURL, {
  getCanonicalUrl,
  getCategoryAndTagUrl,
  prefixProtocol,
  userPath,
} from "discourse/lib/url";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import { setPrefix } from "discourse-common/lib/get-url";

module("Unit | Utility | url", function (hooks) {
  setupTest(hooks);

  test("isInternal with a HTTP url", function (assert) {
    sinon.stub(DiscourseURL, "origin").get(() => "http://eviltrout.com");

    assert.false(DiscourseURL.isInternal(null), "a blank URL is not internal");
    assert.false(
      DiscourseURL.isInternal("ftp::/test.com"),
      "returns false for invalid URLs"
    );
    assert.true(DiscourseURL.isInternal("/test"), "relative URLs are internal");
    assert.true(
      DiscourseURL.isInternal("docs"),
      "non-prefixed relative URLs are internal"
    );
    assert.true(
      DiscourseURL.isInternal("//eviltrout.com"),
      "a url on the same host is internal (protocol-less)"
    );
    assert.true(
      DiscourseURL.isInternal("http://eviltrout.com/tophat"),
      "a url on the same host is internal"
    );
    assert.true(
      DiscourseURL.isInternal("https://eviltrout.com/moustache"),
      "a url on a HTTPS of the same host is internal"
    );
    assert.false(
      DiscourseURL.isInternal("//twitter.com.com"),
      "a different host is not internal (protocol-less)"
    );
    assert.false(
      DiscourseURL.isInternal("http://twitter.com"),
      "a different host is not internal"
    );
    assert.false(
      DiscourseURL.isInternal("ftp://eviltrout.com"),
      "same host, different protocol is not internal"
    );
  });

  test("isInternal with a HTTPS url", function (assert) {
    sinon.stub(DiscourseURL, "origin").get(() => "https://eviltrout.com");
    assert.true(
      DiscourseURL.isInternal("http://eviltrout.com/monocle"),
      "HTTPS urls match HTTP urls"
    );
  });

  test("isInternal on subfolder install", function (assert) {
    sinon.stub(DiscourseURL, "origin").get(() => "http://eviltrout.com/forum");
    assert.false(
      DiscourseURL.isInternal("http://eviltrout.com"),
      "the host root is not internal"
    );
    assert.false(
      DiscourseURL.isInternal("http://eviltrout.com/tophat"),
      "a url on the same host but on a different folder is not internal"
    );
    assert.true(
      DiscourseURL.isInternal("http://eviltrout.com/forum/moustache"),
      "a url on the same host and on the same folder is internal"
    );
  });

  test("userPath", function (assert) {
    assert.strictEqual(userPath(), "/u");
    assert.strictEqual(userPath("eviltrout"), "/u/eviltrout");
  });

  test("userPath with prefix", function (assert) {
    setPrefix("/forum");
    assert.strictEqual(userPath(), "/forum/u");
    assert.strictEqual(userPath("eviltrout"), "/forum/u/eviltrout");
  });

  test("routeTo with prefix", async function (assert) {
    setPrefix("/forum");

    sinon.stub(DiscourseURL, "router").get(() => {
      return {
        currentURL: "/forum",
      };
    });
    sinon.stub(DiscourseURL, "handleURL");
    DiscourseURL.routeTo("/my/messages");
    assert.ok(
      DiscourseURL.handleURL.calledWith(`/my/messages`),
      "it should navigate to the messages page"
    );
  });

  test("routeTo does not rewrite routes started with /my", async function (assert) {
    logIn();
    sinon.stub(DiscourseURL, "router").get(() => {
      return { currentURL: "/" };
    });
    sinon.stub(DiscourseURL, "handleURL");
    DiscourseURL.routeTo("/myfeed");
    assert.ok(
      DiscourseURL.handleURL.calledWith(`/myfeed`),
      "it should navigate to the unmodified route"
    );
  });

  test("prefixProtocol", async function (assert) {
    assert.strictEqual(
      prefixProtocol("mailto:mr-beaver@aol.com"),
      "mailto:mr-beaver@aol.com"
    );
    assert.strictEqual(
      prefixProtocol("discourse.org"),
      "https://discourse.org"
    );
    assert.strictEqual(
      prefixProtocol("www.discourse.org"),
      "https://www.discourse.org"
    );
    assert.strictEqual(
      prefixProtocol("www.discourse.org/mailto:foo"),
      "https://www.discourse.org/mailto:foo"
    );
  });

  test("getCategoryAndTagUrl", function (assert) {
    assert.strictEqual(
      getCategoryAndTagUrl(
        { path: "/c/foo/1", default_list_filter: "all" },
        true
      ),
      "/c/foo/1"
    );

    assert.strictEqual(
      getCategoryAndTagUrl(
        { path: "/c/foo/1", default_list_filter: "all" },
        false
      ),
      "/c/foo/1/none"
    );

    assert.strictEqual(
      getCategoryAndTagUrl(
        { path: "/c/foo/1", default_list_filter: "none" },
        true
      ),
      "/c/foo/1/all"
    );

    assert.strictEqual(
      getCategoryAndTagUrl(
        { path: "/c/foo/1", default_list_filter: "none" },
        false
      ),
      "/c/foo/1/none"
    );
  });

  test("routeTo redirects secure uploads URLS because they are server side only", async function (assert) {
    sinon.stub(DiscourseURL, "redirectTo");
    sinon.stub(DiscourseURL, "handleURL");
    DiscourseURL.routeTo("/secure-uploads/original/1X/test.pdf");
    assert.ok(
      DiscourseURL.redirectTo.calledWith("/secure-uploads/original/1X/test.pdf")
    );
  });

  test("anchor handling", async function (assert) {
    sinon.stub(DiscourseURL, "jumpToElement");
    sinon.stub(DiscourseURL, "replaceState");
    DiscourseURL.routeTo("#heading1");
    assert.ok(
      DiscourseURL.jumpToElement.calledWith("heading1"),
      "in-page anchors call jumpToElement"
    );
    assert.ok(
      DiscourseURL.replaceState.calledWith("#heading1"),
      "in-page anchors call replaceState with the url fragment"
    );
  });

  test("getCanonicalUrl", function (assert) {
    assert.strictEqual(
      getCanonicalUrl("http://eviltrout.com/t/this-is-a-test/1/"),
      "http://eviltrout.com/t/this-is-a-test/1",
      "trailing slashes are removed"
    );

    assert.strictEqual(
      getCanonicalUrl(
        "http://eviltrout.com/t/this-is-a-test/1/?page=2&u=john&not_allowed=true"
      ),
      "http://eviltrout.com/t/this-is-a-test/1?page=2",
      "disallowed query params are removed"
    );

    assert.strictEqual(
      getCanonicalUrl("http://eviltrout.com/t/this-is-a-test/2"),
      "http://eviltrout.com/t/this-is-a-test/2",
      "canonical urls are not modified"
    );

    assert.strictEqual(
      getCanonicalUrl("http://eviltrout.com/t/this-is-a-test/2/?"),
      "http://eviltrout.com/t/this-is-a-test/2",
      "trailing /? are removed"
    );

    assert.strictEqual(
      getCanonicalUrl("http://eviltrout.com/t/this-is-a-test/2?"),
      "http://eviltrout.com/t/this-is-a-test/2",
      "trailing ? are removed"
    );
  });
});
