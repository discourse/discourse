import DiscourseURL from 'discourse/lib/url';

module("lib:url");

test("isInternal with a HTTP url", function() {
  sandbox.stub(DiscourseURL, "origin").returns("http://eviltrout.com");

  not(DiscourseURL.isInternal(null), "a blank URL is not internal");
  ok(DiscourseURL.isInternal("/test"), "relative URLs are internal");
  ok(DiscourseURL.isInternal("http://eviltrout.com/tophat"), "a url on the same host is internal");
  ok(DiscourseURL.isInternal("https://eviltrout.com/moustache"), "a url on a HTTPS of the same host is internal");
  not(DiscourseURL.isInternal("http://twitter.com"), "a different host is not internal");
});

test("isInternal with a HTTPS url", function() {
  sandbox.stub(DiscourseURL, "origin").returns("https://eviltrout.com");
  ok(DiscourseURL.isInternal("http://eviltrout.com/monocle"), "HTTPS urls match HTTP urls");
});
