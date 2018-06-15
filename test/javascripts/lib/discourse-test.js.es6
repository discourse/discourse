QUnit.module("lib:discourse");

QUnit.test("getURL on subfolder install", assert => {
  Discourse.BaseUri = "/forum";
  assert.equal(Discourse.getURL("/"), "/forum/", "root url has subfolder");
  assert.equal(
    Discourse.getURL("/u/neil"),
    "/forum/u/neil",
    "relative url has subfolder"
  );
});
