import { acceptance } from "helpers/qunit-helpers";
acceptance("Static");

QUnit.test("Static Pages", assert => {
  visit("/faq");
  andThen(() => {
    assert.ok($("body.static-faq").length, "has the body class");
    assert.ok(exists(".body-page"), "The content is present");
  });

  visit("/guidelines");
  andThen(() => {
    assert.ok($("body.static-guidelines").length, "has the body class");
    assert.ok(exists(".body-page"), "The content is present");
  });

  visit("/tos");
  andThen(() => {
    assert.ok($("body.static-tos").length, "has the body class");
    assert.ok(exists(".body-page"), "The content is present");
  });

  visit("/privacy");
  andThen(() => {
    assert.ok($("body.static-privacy").length, "has the body class");
    assert.ok(exists(".body-page"), "The content is present");
  });

  visit("/login");
  andThen(() => {
    assert.equal(
      currentPath(),
      "discovery.latest",
      "it redirects them to latest unless `login_required`"
    );
  });
});
