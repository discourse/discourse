import { acceptance } from "helpers/qunit-helpers";

acceptance("Header (Staff)", { loggedIn: true });

test("header", () => {
  visit("/");

  // User dropdown
  click("#current-user");
  andThen(() => {
    ok(exists(".user-menu:visible"), "is lazily rendered after user opens it");
    ok(exists(".user-menu .menu-links-header"), "has showing / hiding user-dropdown links correctly bound");
  });
});
