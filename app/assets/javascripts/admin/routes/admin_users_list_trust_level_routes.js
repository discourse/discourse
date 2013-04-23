/**
  Handles the route that lists users at trust level 0.

  @class AdminUsersListNewuserRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminUsersListNewuserRoute = Discourse.Route.extend({
  setupController: function() {
    return this.controllerFor('adminUsersList').show('newuser');
  }  
});

/**
  Handles the route that lists users at trust level 1.

  @class AdminUsersListBasicRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminUsersListBasicRoute = Discourse.Route.extend({
  setupController: function() {
    return this.controllerFor('adminUsersList').show('basic');
  }  
});

/**
  Handles the route that lists users at trust level 2.

  @class AdminUsersListRegularRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminUsersListRegularRoute = Discourse.Route.extend({
  setupController: function() {
    return this.controllerFor('adminUsersList').show('regular');
  }  
});

/**
  Handles the route that lists users at trust level 3.

  @class AdminUsersListLeadersRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminUsersListLeadersRoute = Discourse.Route.extend({
  setupController: function() {
    return this.controllerFor('adminUsersList').show('leader');
  }  
});

/**
  Handles the route that lists users at trust level 4.

  @class AdminUsersListEldersRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminUsersListEldersRoute = Discourse.Route.extend({
  setupController: function() {
    return this.controllerFor('adminUsersList').show('elder');
  }  
});