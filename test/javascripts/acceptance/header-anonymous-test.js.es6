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
    ok(exists("#search-dropdown:visible"), "after clicking a button search box opens");
    not(exists("#search-dropdown .heading"), "initially, immediately after opening, search box is empty");
  });

  // Perform Search
  // TODO how do I fix the fixture to be a POST instead of a GET @eviltrout
  // fillIn("#search-term", "hello");
  // andThen(() => {
  //   ok(exists("#search-dropdown .heading"), "when user completes a search, search box shows search results");
  //   equal(find("#search-dropdown .results a:first").attr("href"), "/t/hello-bar-integration-issues/17638", "there is a search result");
  // });
});
