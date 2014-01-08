module("Discourse.URL");

test("navigatedToHome", function() {
  var fakeListController = { refresh: function() { return true; } };
  var mock = sinon.mock(fakeListController);
  this.stub(Discourse.URL, "controllerFor").returns(fakeListController);

  mock.expects("refresh").twice();
  ok(Discourse.URL.navigatedToHome("/", "/"));

  var defaultFilter = "/" + Discourse.ListController.filters[0];
  ok(Discourse.URL.navigatedToHome(defaultFilter, "/"));

  ok(!Discourse.URL.navigatedToHome("/old", "/new"));

  // make sure we called the .refresh() method
  mock.verify();
});
