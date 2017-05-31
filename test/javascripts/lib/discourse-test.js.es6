module("lib:discourse");

test("getURL on subfolder install", function() {
  Discourse.BaseUri = "/forum";
  equal(Discourse.getURL("/"), "/forum/", "root url has subfolder");
  equal(Discourse.getURL("/u/neil"), "/forum/u/neil", "relative url has subfolder");
});
