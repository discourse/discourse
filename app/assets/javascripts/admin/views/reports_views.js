/**
  These views are needed so we can render the same template multiple times on
  the admin dashboard.
**/
var opts = { templateName: 'admin/templates/report', tagName: 'tbody' };
Discourse.AdminSignupsView = Discourse.View.extend(opts);
Discourse.AdminVisitsView  = Discourse.View.extend(opts);
Discourse.AdminTopicsView  = Discourse.View.extend(opts);
Discourse.AdminPostsView  = Discourse.View.extend(opts);