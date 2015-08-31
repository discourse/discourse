import UserBadge from 'discourse/models/user-badge';

export default Ember.ArrayController.extend({
  needs: ["adminUser"],
  user: Em.computed.alias('controllers.adminUser.model'),
  sortProperties: ['granted_at'],
  sortAscending: false,

  groupedBadges: function(){
    const allBadges = this.get('model');

    var grouped = _.groupBy(allBadges, badge => badge.badge_id);

    var expanded = [];
    const expandedBadges = allBadges.get('expandedBadges');

    _(grouped).each(function(badges){
      var lastGranted = badges[0].granted_at;

      _.each(badges, function(badge) {
        lastGranted = lastGranted < badge.granted_at ? badge.granted_at : lastGranted;
      });

      if(badges.length===1 || _.include(expandedBadges, badges[0].badge.id)){
        _.each(badges, badge => expanded.push(badge));
        return;
      }

      var result = {
        badge: badges[0].badge,
        granted_at: lastGranted,
        badges: badges,
        count: badges.length,
        grouped: true
      };

      expanded.push(result);
    });

    return _(expanded).sortBy(group => group.granted_at).reverse().value();


  }.property('model', 'model.@each', 'model.expandedBadges.@each'),

  /**
    Array of badges that have not been granted to this user.

    @property grantableBadges
    @type {Boolean}
  **/
  grantableBadges: function() {
    var granted = {};
    this.get('model').forEach(function(userBadge) {
      granted[userBadge.get('badge_id')] = true;
    });

    var badges = [];
    this.get('badges').forEach(function(badge) {
      if (badge.get('multiple_grant') || !granted[badge.get('id')]) {
        badges.push(badge);
      }
    });

    return _.sortBy(badges, "name");
  }.property('badges.@each', 'model.@each'),

  /**
    Whether there are any badges that can be granted.

    @property noBadges
    @type {Boolean}
  **/
  noBadges: Em.computed.empty('grantableBadges'),

  actions: {

    expandGroup: function(userBadge){
      const model = this.get('model');
      model.set('expandedBadges', model.get('expandedBadges') || []);
      model.get('expandedBadges').pushObject(userBadge.badge.id);
    },

    /**
      Grant the selected badge to the user.

      @method grantBadge
      @param {Integer} badgeId id of the badge we want to grant.
    **/
    grantBadge: function(badgeId) {
      var self = this;
      UserBadge.grant(badgeId, this.get('user.username'), this.get('badgeReason')).then(function(userBadge) {
        self.set('badgeReason', '');
        self.pushObject(userBadge);
        Ember.run.next(function() {
          // Update the selected badge ID after the combobox has re-rendered.
          var newSelectedBadge = self.get('grantableBadges')[0];
          if (newSelectedBadge) {
            self.set('selectedBadgeId', newSelectedBadge.get('id'));
          }
        });
      }, function() {
        // Failure
        bootbox.alert(I18n.t('generic_error'));
      });
    },

    revokeBadge: function(userBadge) {
      var self = this;
      return bootbox.confirm(I18n.t("admin.badges.revoke_confirm"), I18n.t("no_value"), I18n.t("yes_value"), function(result) {
        if (result) {
          userBadge.revoke().then(function() {
            self.get('model').removeObject(userBadge);
          });
        }
      });
    }

  }
});
