export default Ember.ContainerView.extend({

  attachViewWithArgs(viewArgs, viewClass) {
    if (!viewClass) { viewClass = Ember.View.extend(); }
    this.pushObject(this.createChildView(viewClass, viewArgs));
  },

  attachViewClass(viewClass) {
    this.attachViewWithArgs(null, viewClass);
  }
});
