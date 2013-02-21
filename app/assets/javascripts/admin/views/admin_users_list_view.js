(function() {

  /**
    A view for listing users in the admin section

    @class AdminUsersListView    
    @extends Discourse.View
    @namespace Discourse
    @module Discourse
  **/
  Discourse.AdminUsersListView = window.Discourse.View.extend({
    templateName: 'admin/templates/users_list'
  });

}).call(this);
