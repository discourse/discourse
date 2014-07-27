Discourse.AdminBadgesRoute = Discourse.Route.extend({
  setupController: function(controller) {
    Discourse.ajax('/admin/badges.json').then(function(json){

      controller.set('badgeGroupings', Em.A(json.badge_groupings));
      controller.set('badgeTypes', json.badge_types);
      controller.set('protectedSystemFields', json.admin_badges.protected_system_fields);
      var triggers = [];
      _.each(json.admin_badges.triggers,function(v,k){
        triggers.push({id: v, name: I18n.t('admin.badges.trigger_type.'+k)});
      });
      controller.set('badgeTriggers', triggers);
      controller.set('model', Discourse.Badge.createFromJson(json));
    });
  },

  actions: {
    editGroupings: function(model){
      Discourse.Route.showModal(this, 'admin_edit_badge_groupings', model);
    }
  }

});
