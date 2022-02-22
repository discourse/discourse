import DiscourseURL, {
  getCategoryAndTagUrl,
  prefixProtocol,
  userPath,
} from "discourse/lib/url";
import { module, test } from "qunit";
import User from "discourse/models/user";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import { setPrefix } from "discourse-common/lib/get-url";
import sinon from "sinon";

module("Unit | Utility | url", function () {
  test("isInternal with a HTTP url", function (assert) {
    sinon.stub(DiscourseURL, "origin").returns("http://eviltrout.com");

    assert.notOk(DiscourseURL.isInternal(null), "a blank URL is not internal");
    assert.ok(DiscourseURL.isInternal("/test"), "relative URLs are internal");
    assert.ok(
      DiscourseURL.isInternal("//eviltrout.com"),
      "a url on the same host is internal (protocol-less)"
    );
    assert.ok(
      DiscourseURL.isInternal("http://eviltrout.com/tophat"),
      "a url on the same host is internal"
    );
    assert.ok(
      DiscourseURL.isInternal("https://eviltrout.com/moustache"),
      "a url on a HTTPS of the same host is internal"
    );
    assert.notOk(
      DiscourseURL.isInternal("//twitter.com.com"),
      "a different host is not internal (protocol-less)"
    );
    assert.notOk(
      DiscourseURL.isInternal("http://twitter.com"),
      "a different host is not internal"
    );
  });

  test("isInternal with a HTTPS url", function (assert) {
    sinon.stub(DiscourseURL, "origin").returns("https://eviltrout.com");
    assert.ok(
      DiscourseURL.isInternal("http://eviltrout.com/monocle"),
      "HTTPS urls match HTTP urls"
    );
  });

  test("isInternal on subfolder install", function (assert) {
    sinon.stub(DiscourseURL, "origin").returns("http://eviltrout.com/forum");
    assert.notOk(
      DiscourseURL.isInternal("http://eviltrout.com"),
      "the host root is not internal"
    );
    assert.notOk(
      DiscourseURL.isInternal("http://eviltrout.com/tophat"),
      "a url on the same host but on a different folder is not internal"
    );
    assert.ok(
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
    logIn();
    const user = User.current();

    sinon.stub(DiscourseURL, "router").get(() => {
      return {
        currentURL: "/forum",
      };
    });
    sinon.stub(DiscourseURL, "handleURL");
    DiscourseURL.routeTo("/my/messages");
    assert.ok(
      DiscourseURL.handleURL.calledWith(`/u/${user.username}/messages`),
      "it should navigate to the messages page"
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
      "/c/foo/1"
    );
  });

  test("routeTo redirects secure media URLS because they are server side only", async function (assert) {
    sinon.stub(DiscourseURL, "redirectTo");
    sinon.stub(DiscourseURL, "handleURL");
    DiscourseURL.routeTo("/secure-media-uploads/original/1X/test.pdf");
    assert.ok(
      DiscourseURL.redirectTo.calledWith(
        "/secure-media-uploads/original/1X/test.pdf"
      )
    );
  });
});
