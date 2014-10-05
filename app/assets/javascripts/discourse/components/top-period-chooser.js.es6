import CleansUp from 'discourse/mixins/cleans-up';

export default Ember.Component.extend(CleansUp, {
  classNames: 'period-chooser',
  showPeriods: false,

  cleanUp: function() {
    this.set('showPeriods', false);
    $('html').off('mousedown.top-period');
  },

  _clickToClose: function() {
    var self = this;
    $('html').off('mousedown.top-period').on('mousedown.top-period', function(e) {
      var $target = $(e.target);
      if (($target.prop('id') === 'topic-entrance') || (self.$().has($target).length !== 0)) {
        return;
      }
      self.cleanUp();
    });
  },

  click: function() {
    if (!this.get('showPeriods')) {
      var $chevron = this.$('i.fa-caret-down');
      this.$('#period-popup').css($chevron.position());
      this.set('showPeriods', true);
      this._clickToClose();
    }
  }
});
