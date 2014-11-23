import UserActivityRoute from 'discourse/routes/user-activity';

export default UserActivityRoute.extend({
  actions: {
    willTransition: function() {
      this._super();
      this.controllerFor('user').set('pmView', null);
      return true;
    }
  }
});
