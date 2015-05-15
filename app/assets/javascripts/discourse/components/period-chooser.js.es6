import CleansUp from 'discourse/mixins/cleans-up';

export default Ember.Component.extend(CleansUp, {
  classNames: 'period-chooser',
  showPeriods: false,

  cleanUp: function() {
    this.set('showPeriods', false);
    $('html').off('mousedown.top-period');
  },

  _clickToClose: function() {
    const self = this;
    $('html').off('mousedown.top-period').on('mousedown.top-period', function(e) {
      const $target = $(e.target);
      if (($target.prop('id') === 'topic-entrance') || (self.$().has($target).length !== 0)) {
        return;
      }
      self.cleanUp();
    });
  },

  click(e) {
    if ($(e.target).closest('.period-popup').length) { return; }

    if (!this.get('showPeriods')) {
      const $chevron = this.$('i.fa-caret-down');
      this.$('#period-popup').css($chevron.position());
      this.set('showPeriods', true);
      this._clickToClose();
    }
  },

  actions: {
    changePeriod(p) {
      this.cleanUp();
      this.set('period', p);
      this.sendAction('action', p);
    }
  }

});
