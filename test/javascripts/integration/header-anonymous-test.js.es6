integration("Header (Anonymous)");

test("header", () => {
  visit("/");
  andThen(() => {
    ok(exists("header"), "is rendered");
    ok(exists(".logo-big"), "it renders the large logo by default");
    not(exists("#notifications-dropdown li"), "no notifications at first");
    not(exists('#site-map-dropdown'), "no site map by default");
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

  // Site Map
  click("#site-map");
  andThen(() => {
    ok(exists('#site-map-dropdown'), "is rendered after user opens it");
    ok(exists("#site-map-dropdown .faq-link"), "it shows the faq link");
    ok(exists("#site-map-dropdown .category-links"), "has categories correctly bound");
  });

  // Search
  click("#search-button");
  andThen(() => {
    ok(exists("#search-dropdown:visible"), "after clicking a button search box opens");
    not(exists("#search-dropdown .heading"), "initially, immediately after opening, search box is empty");
  });

  // Perform Search
  fillIn("#search-term", "hello");
  andThen(() => {
    ok(exists("#search-dropdown .heading"), "when user completes a search, search box shows search results");
    equal(find("#search-dropdown .results a:first").attr("href"), "/t/hello-bar-integration-issues/17638", "there is a search result");
  });
});
