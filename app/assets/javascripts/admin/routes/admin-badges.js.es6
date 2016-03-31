import Badge from 'discourse/models/badge';
import BadgeGrouping from 'discourse/models/badge-grouping';

export default Discourse.Route.extend({
  _json: null,

  model: function() {
    var self = this;
    return Discourse.ajax('/admin/badges.json').then(function(json) {
      self._json = json;
      return Badge.createFromJson(json);
    });
  },

  setupController: function(controller, model) {
    var json = this._json,
        triggers = [],
        badgeGroupings = [];

    _.each(json.admin_badges.triggers,function(v,k){
      triggers.push({id: v, name: I18n.t('admin.badges.trigger_type.'+k)});
    });

    json.badge_groupings.forEach(function(badgeGroupingJson) {
      badgeGroupings.push(BadgeGrouping.create(badgeGroupingJson));
    });

    controller.setProperties({
      badgeGroupings: badgeGroupings,
      badgeTypes: json.badge_types,
      protectedSystemFields: json.admin_badges.protected_system_fields,
      badgeTriggers: triggers,
      model: model
    });
  }
});
