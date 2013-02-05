Discourse.AdminUsersListNewRoute = Discourse.Route.extend
  setupController: (c) -> @controllerFor('adminUsersList').show('pending')   