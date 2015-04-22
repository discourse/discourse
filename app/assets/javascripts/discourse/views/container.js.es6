import Presence from 'discourse/mixins/presence';

export default Ember.ContainerView.extend(Presence, {

  attachViewWithArgs(viewArgs, viewClass) {
    if (!viewClass) { viewClass = Ember.View.extend(); }
    this.pushObject(this.createChildView(viewClass, viewArgs));
  },

  attachViewClass(viewClass) {
    this.attachViewWithArgs(null, viewClass);
  }
});
