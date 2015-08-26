import { acceptance } from "helpers/qunit-helpers";
acceptance("Header (Anonymous)");

test("header", () => {
  visit("/");
  andThen(() => {
    ok(exists("header"), "is rendered");
    ok(exists(".logo-big"), "it renders the large logo by default");
    not(exists("#notifications-dropdown li"), "no notifications at first");
    not(exists("#user-dropdown:visible"), "initially user dropdown is closed");
    not(exists("#search-dropdown:visible"), "initially search box is closed");
  });

  // Logo changing
  andThen(() => {
    controllerFor('header').set("showExtraInfo", true);
  });

  andThen(() => {
    ok(exists(".logo-small"), "it shows the small logo when `showExtraInfo` is enabled");
  });

  // Search
  click("#search-button");
  andThen(() => {
    ok(exists(".search-menu:visible"), "after clicking a button search box opens");
    not(exists(".search-menu .heading"), "initially, immediately after opening, search box is empty");
  });

});
