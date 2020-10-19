import { test, module } from "qunit";
import DiscourseURL, { userPath, prefixProtocol } from "discourse/lib/url";
import { setPrefix } from "discourse-common/lib/get-url";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import User from "discourse/models/user";

module("lib:url");

test("isInternal with a HTTP url", (assert) => {
  sandbox.stub(DiscourseURL, "origin").returns("http://eviltrout.com");

  assert.not(DiscourseURL.isInternal(null), "a blank URL is not internal");
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
  assert.not(
    DiscourseURL.isInternal("//twitter.com.com"),
    "a different host is not internal (protocol-less)"
  );
  assert.not(
    DiscourseURL.isInternal("http://twitter.com"),
    "a different host is not internal"
  );
});

test("isInternal with a HTTPS url", (assert) => {
  sandbox.stub(DiscourseURL, "origin").returns("https://eviltrout.com");
  assert.ok(
    DiscourseURL.isInternal("http://eviltrout.com/monocle"),
    "HTTPS urls match HTTP urls"
  );
});

test("isInternal on subfolder install", (assert) => {
  sandbox.stub(DiscourseURL, "origin").returns("http://eviltrout.com/forum");
  assert.not(
    DiscourseURL.isInternal("http://eviltrout.com"),
    "the host root is not internal"
  );
  assert.not(
    DiscourseURL.isInternal("http://eviltrout.com/tophat"),
    "a url on the same host but on a different folder is not internal"
  );
  assert.ok(
    DiscourseURL.isInternal("http://eviltrout.com/forum/moustache"),
    "a url on the same host and on the same folder is internal"
  );
});

test("userPath", (assert) => {
  assert.equal(userPath(), "/u");
  assert.equal(userPath("eviltrout"), "/u/eviltrout");
});

test("userPath with prefix", (assert) => {
  setPrefix("/forum");
  assert.equal(userPath(), "/forum/u");
  assert.equal(userPath("eviltrout"), "/forum/u/eviltrout");
});

test("routeTo with prefix", async (assert) => {
  setPrefix("/forum");
  logIn();
  const user = User.current();

  sandbox.stub(DiscourseURL, "handleURL");
  DiscourseURL.routeTo("/my/messages");
  assert.ok(
    DiscourseURL.handleURL.calledWith(`/u/${user.username}/messages`),
    "it should navigate to the messages page"
  );
});

test("prefixProtocol", async (assert) => {
  assert.equal(
    prefixProtocol("mailto:mr-beaver@aol.com"),
    "mailto:mr-beaver@aol.com"
  );
  assert.equal(prefixProtocol("discourse.org"), "https://discourse.org");
  assert.equal(
    prefixProtocol("www.discourse.org"),
    "https://www.discourse.org"
  );
  assert.equal(
    prefixProtocol("www.discourse.org/mailto:foo"),
    "https://www.discourse.org/mailto:foo"
  );
});
