export default Ember.ArrayController.extend({
  needs: ["user"],
  user: Em.computed.alias("controllers.user.model"),
  sortProperties: ['badge.badge_type.sort_order', 'badge.name'],
  orderBy: function(ub1, ub2){
    var sr1 = ub1.get('badge.badge_type.sort_order');
    var sr2 = ub2.get('badge.badge_type.sort_order');


    if(sr1 > sr2) {
      return -1;
    }

    if(sr2 > sr1) {
      return 1;
    }

    return ub1.get('badge.name') < ub2.get('badge.name') ? -1 : 1;
  }
});
