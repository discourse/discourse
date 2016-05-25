const helper = {
  offset: () => window.pageYOffset || $('html').scrollTop()
};

export default Ember.Mixin.create({
  _dockHandler: null,

  didInsertElement() {
    this._super();

    // Check the dock after the current run loop since reading sizes is slow
    this._dockHandler = () => Ember.run.next(() => this.dockCheck(helper));

    $(window).bind('scroll.discourse-dock', this._dockHandler);
    $(document).bind('touchmove.discourse-dock', this._dockHandler);

    this.dockCheck(helper);
  },

  willDestroyElement() {
    this._super();
    $(window).unbind('scroll.discourse-dock', this._dockHandler);
    $(document).unbind('touchmove.discourse-dock', this._dockHandler);
  }
});
