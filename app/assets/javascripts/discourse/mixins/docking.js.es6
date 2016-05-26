const helper = {
  offset: () => window.pageYOffset || $('html').scrollTop()
};

export default Ember.Mixin.create({
  queueDockCheck: null,

  init() {
    this._super();
    this.queueDockCheck = () => {
      Ember.run.debounce(this, this.dockCheck, helper, 5);
    };
  },

  didInsertElement() {
    this._super();

    $(window).bind('scroll.discourse-dock', this.queueDockCheck);
    $(document).bind('touchmove.discourse-dock', this.queueDockCheck);

    this.dockCheck(helper);
  },

  willDestroyElement() {
    this._super();
    $(window).unbind('scroll.discourse-dock', this.queueDockCheck);
    $(document).unbind('touchmove.discourse-dock', this.queueDockCheck);
  }
});
