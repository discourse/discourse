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
    assert.true(DiscourseURL.isInternal("/test"), "relative URLs are internal");
    assert.true(
      DiscourseURL.isInternal("docs"),
      "non-prefixed relative URLs are internal"
    );
    assert.true(DiscourseURL.isInternal("#foo"), "anchor URLs are internal");
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
      "a different protocol is not internal"
    );
    assert.false(
      DiscourseURL.isInternal("ftp::/eviltrout.com"),
      "an invalid URL is not internal"
    );
  });

  test("isInternal with a HTTPS url", function (assert) {
    sinon.stub(DiscourseURL, "origin").get(() => "https://eviltrout.com");
    assert.true(
      DiscourseURL.isInternal("http://eviltrout.com/monocle"),
      "HTTPS urls match HTTP urls"
    );
    assert.true(
      DiscourseURL.isInternal("https://eviltrout.com/monocle"),
      "HTTPS urls match HTTPS urls"
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
    assert.true(DiscourseURL.isInternal("/test"), "relative URLs are internal");
    assert.true(
      DiscourseURL.isInternal("docs"),
      "non-prefixed relative URLs are internal"
    );
    assert.true(DiscourseURL.isInternal("#foo"), "anchor URLs are internal");
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
    assert.true(
      DiscourseURL.handleURL.calledWith(`/my/messages`),
      "navigates to the messages page"
    );
  });

  test("routeTo protocol/domain stripping", async function (assert) {
    sinon.stub(DiscourseURL, "origin").get(() => "http://example.com");
    sinon.stub(DiscourseURL, "handleURL");
    sinon.stub(DiscourseURL, "router").get(() => {
      return {
        currentURL: "/bar",
      };
    });

    DiscourseURL.routeTo("http://example.com/foo1");
    assert.true(
      DiscourseURL.handleURL.calledWith(`/foo1`),
      "strips the protocol and domain when http"
    );

    DiscourseURL.routeTo("https://example.com/foo2");
    assert.true(
      DiscourseURL.handleURL.calledWith(`/foo2`),
      "strips the protocol and domain when https"
    );

    DiscourseURL.routeTo("//example.com/foo3");
    assert.true(
      DiscourseURL.handleURL.calledWith(`/foo3`),
      "strips the protocol and domain when protocol-less"
    );

    DiscourseURL.routeTo("https://example.com/t//1");
    assert.true(
      DiscourseURL.handleURL.calledWith(`/t//1`),
      "does not strip double-slash in the middle of urls"
    );

    DiscourseURL.routeTo("/t//2");
    assert.true(
      DiscourseURL.handleURL.calledWith(`/t//2`),
      "does not strip double-slash in the middle of urls, even without a domain"
    );
  });

  test("routeTo does not rewrite routes started with /my", async function (assert) {
    logIn(this.owner);
    sinon.stub(DiscourseURL, "router").get(() => {
      return { currentURL: "/" };
    });
    sinon.stub(DiscourseURL, "handleURL");
    DiscourseURL.routeTo("/myfeed");
    assert.true(
      DiscourseURL.handleURL.calledWith(`/myfeed`),
      "navigates to the unmodified route"
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
    assert.true(
      DiscourseURL.redirectTo.calledWith("/secure-uploads/original/1X/test.pdf")
    );
  });

  test("anchor handling", async function (assert) {
    sinon.stub(DiscourseURL, "jumpToElement");
    sinon.stub(DiscourseURL, "replaceState");
    DiscourseURL.routeTo("#heading1");
    assert.true(
      DiscourseURL.jumpToElement.calledWith("heading1"),
      "in-page anchors call jumpToElement"
    );
    assert.true(
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
