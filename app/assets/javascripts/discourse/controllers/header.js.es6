const HeaderController = Ember.Controller.extend({
  topic: null,
  showExtraInfo: null,
  hamburgerVisible: false,
  searchVisible: false,
  userMenuVisible: false,
  needs: ['application'],

  canSignUp: Em.computed.alias('controllers.application.canSignUp'),

  showSignUpButton: function() {
    return this.get('canSignUp') && !this.get('showExtraInfo');
  }.property('canSignUp', 'showExtraInfo'),

  showStarButton: function() {
    return Discourse.User.current() && !this.get('topic.isPrivateMessage');
  }.property('topic.isPrivateMessage'),


  actions: {
    toggleStar() {
      const topic = this.get('topic');
      if (topic) topic.toggleStar();
      return false;
    }
  }
});

// Allow plugins to add to the sum of "flags" above the site map
const _flagProperties = [];
function addFlagProperty(prop) {
  _flagProperties.pushObject(prop);
}

function applyFlaggedProperties() {
  const args = _flagProperties.slice();
  args.push(function() {
    let sum = 0;
    _flagProperties.forEach((fp) => sum += (this.get(fp) || 0));
    return sum;
  });
  HeaderController.reopen({ flaggedPostsCount: Ember.computed.apply(this, args) });
}

addFlagProperty('currentUser.site_flagged_posts_count');
addFlagProperty('currentUser.post_queue_new_count');

export { addFlagProperty, applyFlaggedProperties };
export default HeaderController;
