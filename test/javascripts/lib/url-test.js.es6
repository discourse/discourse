module("Discourse.URL");

test("isInternal with a HTTP url", function() {
  sandbox.stub(Discourse.URL, "origin").returns("http://eviltrout.com");

  not(Discourse.URL.isInternal(null), "a blank URL is not internal");
  ok(Discourse.URL.isInternal("/test"), "relative URLs are internal");
  ok(Discourse.URL.isInternal("http://eviltrout.com/tophat"), "a url on the same host is internal");
  ok(Discourse.URL.isInternal("https://eviltrout.com/moustache"), "a url on a HTTPS of the same host is internal");
  not(Discourse.URL.isInternal("http://twitter.com"), "a different host is not internal");
});

test("isInternal with a HTTPS url", function() {
  sandbox.stub(Discourse.URL, "origin").returns("https://eviltrout.com");
  ok(Discourse.URL.isInternal("http://eviltrout.com/monocle"), "HTTPS urls match HTTP urls");
});
