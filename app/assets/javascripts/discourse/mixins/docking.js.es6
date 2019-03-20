const helper = {
  offset() {
    const mainOffset = $("#main").offset();
    const offsetTop = mainOffset ? mainOffset.top : 0;
    return (window.pageYOffset || $("html").scrollTop()) - offsetTop;
  }
};

export default Ember.Mixin.create({
  queueDockCheck: null,

  init() {
    this._super(...arguments);
    this.queueDockCheck = () => {
      Ember.run.debounce(this, this.safeDockCheck, 5);
    };
  },

  safeDockCheck() {
    if (this.isDestroyed || this.isDestroying) {
      return;
    }
    this.dockCheck(helper);
  },

  didInsertElement() {
    this._super(...arguments);

    $(window).bind("scroll.discourse-dock", this.queueDockCheck);
    $(document).bind("touchmove.discourse-dock", this.queueDockCheck);

    this.dockCheck(helper);
  },

  willDestroyElement() {
    this._super(...arguments);
    $(window).unbind("scroll.discourse-dock", this.queueDockCheck);
    $(document).unbind("touchmove.discourse-dock", this.queueDockCheck);
  }
});
