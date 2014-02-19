module("Discourse.URL");

test("isInternal with a HTTP url", function() {
  this.stub(Discourse.URL, "origin").returns("http://eviltrout.com");

  not(Discourse.URL.isInternal(null), "a blank URL is not internal");
  ok(Discourse.URL.isInternal("/test"), "relative URLs are internal");
  ok(Discourse.URL.isInternal("http://eviltrout.com/tophat"), "a url on the same host is internal");
  ok(Discourse.URL.isInternal("https://eviltrout.com/moustache"), "a url on a HTTPS of the same host is internal");
  not(Discourse.URL.isInternal("http://twitter.com"), "a different host is not internal");
});

test("isInternal with a HTTPS url", function() {
  this.stub(Discourse.URL, "origin").returns("https://eviltrout.com");
  ok(Discourse.URL.isInternal("http://eviltrout.com/monocle"), "HTTPS urls match HTTP urls");
});

// --------------------------------------------
// I DON'T KNOW WHY THIS BREAKS OTHER TESTS :(
  // --------------------------------------------

// test("routeTo", function() {
//   this.stub(Discourse.URL, "handleURL", function (path) { return path === "/t/topic-title/42"; });

//   ok(Discourse.URL.routeTo("https://discourse.org/t/topic-title/42"), "can route HTTPS");
//   ok(Discourse.URL.routeTo("http://discourse.org/t/topic-title/42"), "can route HTTP");
//   ok(Discourse.URL.routeTo("//discourse.org/t/topic-title/42"), "can route schemaless");
//   ok(Discourse.URL.routeTo("/t/topic-title/42"), "can route relative");
// });

test("navigatedToHome", function() {
  var fakeDiscoveryController = { send: function() { return true; } };
  var mock = sinon.mock(fakeDiscoveryController);
  this.stub(Discourse.URL, "controllerFor").returns(fakeDiscoveryController);

  mock.expects("send").withArgs('refresh').twice();
  ok(Discourse.URL.navigatedToHome("/", "/"));

  var homepage = "/" + Discourse.Utilities.defaultHomepage();
  ok(Discourse.URL.navigatedToHome(homepage, "/"));

  not(Discourse.URL.navigatedToHome("/old", "/new"));

  // make sure we called the .refresh() method
  mock.verify();
});
