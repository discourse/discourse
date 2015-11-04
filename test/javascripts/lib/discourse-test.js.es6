module("lib:discourse");

test("getURL on subfolder install", function() {
  Discourse.BaseUri = "/forum";
  equal(Discourse.getURL("/"), "/forum/", "root url has subfolder");
  equal(Discourse.getURL("/users/neil"), "/forum/users/neil", "relative url has subfolder");
});