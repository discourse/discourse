import { default as DiscourseURL, userPath } from "discourse/lib/url";

QUnit.module("lib:url");

QUnit.test("isInternal with a HTTP url", assert => {
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

QUnit.test("isInternal with a HTTPS url", assert => {
  sandbox.stub(DiscourseURL, "origin").returns("https://eviltrout.com");
  assert.ok(
    DiscourseURL.isInternal("http://eviltrout.com/monocle"),
    "HTTPS urls match HTTP urls"
  );
});

QUnit.test("isInternal on subfolder install", assert => {
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

QUnit.test("userPath", assert => {
  assert.equal(userPath(), "/u");
  assert.equal(userPath("eviltrout"), "/u/eviltrout");
  assert.equal(userPath("hp.json"), "/u/hp.json");
});

QUnit.test("userPath with BaseUri", assert => {
  Discourse.BaseUri = "/forum";
  assert.equal(userPath(), "/forum/u");
  assert.equal(userPath("eviltrout"), "/forum/u/eviltrout");
  assert.equal(userPath("hp.json"), "/forum/u/hp.json");
});
