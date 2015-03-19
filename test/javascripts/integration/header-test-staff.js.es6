integration("Header (Staff)", {
  user: { username: 'test',
          staff: true,
          site_flagged_posts_count: 1 }
});

test("header", () => {
  visit("/");

  // Notifications
  click("#user-notifications");
  andThen(() => {
    var $items = $("#notifications-dropdown li");
    ok(exists($items), "is lazily populated after user opens it");
    ok($items.first().hasClass("read"), "correctly binds items' 'read' class");
  });

  // Site Map
  click("#site-map");
  andThen(() => {
    ok(exists("#site-map-dropdown .admin-link"), "it has the admin link");
    ok(exists("#site-map-dropdown .flagged-posts.badge-notification"), "it displays flag notifications");
  });

  // User dropdown
  click("#current-user");
  andThen(() => {
    ok(exists("#user-dropdown:visible"), "is lazily rendered after user opens it");
    ok(exists("#user-dropdown .user-dropdown-links"), "has showing / hiding user-dropdown links correctly bound");
  });
});
