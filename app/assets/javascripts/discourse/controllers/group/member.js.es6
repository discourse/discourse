import ObjectController from 'discourse/controllers/object';

export default ObjectController.extend({
  needs: ['group/members'],

  canManageGroup: function() {
    return this.get('controllers.group/members.canManageGroup');;
  }.property(),

  actions: {
    removeMe: function() {
      var members = this.get('controllers.group/members');
      members.removeMember(this.model);
    }
  }

});
