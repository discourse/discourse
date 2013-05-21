/**
  Handles the route that deals with listing users

  @class AdminUsersListRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminUsersListRoute = Discourse.Route.extend({
  renderTemplate: function() {
    this.render('admin/templates/users_list', {into: 'admin/templates/admin'});
  }
});

/**
  Handles the route that lists active users.

  @class AdminUsersListActiveRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminUsersListActiveRoute = Discourse.Route.extend({
  setupController: function() {
    return this.controllerFor('adminUsersList').show('active');
  }
});

/**
  Handles the route that lists new users.

  @class AdminUsersListNewRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminUsersListNewRoute = Discourse.Route.extend({
  setupController: function() {
    return this.controllerFor('adminUsersList').show('new');
  }
});

/**
  Handles the route that lists pending users.

  @class AdminUsersListNewRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminUsersListPendingRoute = Discourse.Route.extend({
  setupController: function() {
    return this.controllerFor('adminUsersList').show('pending');
  }
});

/**
  Handles the route that lists admin users.

  @class AdminUsersListAdminsRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminUsersListAdminsRoute = Discourse.Route.extend({
  setupController: function() {
    return this.controllerFor('adminUsersList').show('admins');
  }
});

/**
  Handles the route that lists moderators.

  @class AdminUsersListModeratorsRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminUsersListModeratorsRoute = Discourse.Route.extend({
  setupController: function() {
    return this.controllerFor('adminUsersList').show('moderators');
  }
});