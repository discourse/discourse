export default Ember.ContainerView.extend({

  attachViewWithArgs(viewArgs, viewClass) {
    if (typeof viewClass === "string") {
      viewClass = this.container.lookupFactory("view:" + viewClass) ||
                  this.container.lookupFactory("component:" + viewClass);
    }

    if (!viewClass) { viewClass = Ember.View.extend(); }
    this.pushObject(this.createChildView(viewClass, viewArgs));
  },

  attachViewClass(viewClass) {
    this.attachViewWithArgs(null, viewClass);
  }
});
