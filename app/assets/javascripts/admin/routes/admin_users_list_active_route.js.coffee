Discourse.AdminUsersListActiveRoute = Discourse.Route.extend
  setupController: (c) -> @controllerFor('adminUsersList').show('active')