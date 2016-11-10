import { acceptance } from "helpers/qunit-helpers";
acceptance("Static");

test("Static Pages", () => {
  visit("/faq");
  andThen(() => {
    ok($('body.static-faq').length, "has the body class");
    ok(exists(".body-page"), "The content is present");
  });

  visit("/guidelines");
  andThen(() => {
    ok($('body.static-guidelines').length, "has the body class");
    ok(exists(".body-page"), "The content is present");
  });

  visit("/tos");
  andThen(() => {
    ok($('body.static-tos').length, "has the body class");
    ok(exists(".body-page"), "The content is present");
  });

  visit("/privacy");
  andThen(() => {
    ok($('body.static-privacy').length, "has the body class");
    ok(exists(".body-page"), "The content is present");
  });

  visit("/login");
  andThen(() => {
    equal(currentPath(), "discovery.latest", "it redirects them to latest unless `login_required`");
  });
});
