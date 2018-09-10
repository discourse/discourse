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

QUnit.test("getURLWithCDN on subfolder install with S3", assert => {
  Discourse.BaseUri = "/forum";

  Discourse.S3CDN = "https://awesome.cdn/site";
  Discourse.S3BaseUrl = "//test.s3-us-west-1.amazonaws.com/site";

  let url = "//test.s3-us-west-1.amazonaws.com/site/forum/awesome.png";
  let expected = "https://awesome.cdn/site/forum/awesome.png";

  assert.equal(Discourse.getURLWithCDN(url), expected, "at correct path");

  Discourse.S3CDN = null;
  Discourse.S3BaseUrl = null;
});
