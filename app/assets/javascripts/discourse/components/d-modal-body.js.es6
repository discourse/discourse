export default Ember.Component.extend({
  classNames: ['modal-body'],

  didInsertElement() {
    this._super();
    $('#modal-alert').hide();
    $('#discourse-modal').modal('show');
    Ember.run.scheduleOnce('afterRender', this, this._afterFirstRender);
  },

  _afterFirstRender() {
    if (!this.site.mobileView && this.get('autoFocus') !== 'false') {
      this.$('input:first').focus();
    }

    const maxHeight = this.get('maxHeight');
    if (maxHeight) {
      const maxHeightFloat = parseFloat(maxHeight) / 100.0;
      if (maxHeightFloat > 0) {
        const viewPortHeight = $(window).height();
        this.$().css("max-height", Math.floor(maxHeightFloat * viewPortHeight) + "px");
      }
    }

    this.appEvents.trigger('modal:body-shown', {
      title: this.get('title')
    });
  }
});
