import { acceptance } from "helpers/qunit-helpers";
acceptance("Static");

test("Static Pages", () => {
  visit("/faq");
  andThen(() => {
    ok(exists(".body-page"), "The content is present");
  });

  visit("/guidelines");
  andThen(() => {
    ok(exists(".body-page"), "The content is present");
  });

  visit("/tos");
  andThen(() => {
    ok(exists(".body-page"), "The content is present");
  });

  visit("/privacy");
  andThen(() => {
    ok(exists(".body-page"), "The content is present");
  });

  visit("/login");
  andThen(() => {
    equal(currentPath(), "discovery.latest", "it redirects them to latest unless `login_required`");
  });
});
