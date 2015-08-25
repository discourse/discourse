import { acceptance } from "helpers/qunit-helpers";

acceptance("Header (Staff)", { loggedIn: true });

test("header", () => {
  visit("/");

  // Notifications
  click("#user-notifications");
  andThen(() => {
    var $items = $("#notifications-dropdown li");
    ok(exists($items), "is lazily populated after user opens it");
    ok($items.first().hasClass("read"), "correctly binds items' 'read' class");
  });

  // User dropdown
  click("#current-user");
  andThen(() => {
    ok(exists("#user-dropdown:visible"), "is lazily rendered after user opens it");
    ok(exists("#user-dropdown .user-dropdown-links"), "has showing / hiding user-dropdown links correctly bound");
  });
});
