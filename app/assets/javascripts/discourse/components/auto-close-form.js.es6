export default Ember.Component.extend({
  autoCloseValid: false,

  label: function() {
    return I18n.t( this.get('labelKey') || 'composer.auto_close_label' );
  }.property('labelKey'),

  autoCloseChanged: function() {
    if( this.get('autoCloseTime') && this.get('autoCloseTime').length > 0 ) {
      this.set('autoCloseTime', this.get('autoCloseTime').replace(/[^:\d-\s]/g, '') );
    }
    this.set('autoCloseValid', this.isAutoCloseValid());
  }.observes('autoCloseTime'),

  isAutoCloseValid: function() {
    if (this.get('autoCloseTime')) {
      var t = this.get('autoCloseTime').trim();
      if (t.match(/^[\d]{4}-[\d]{1,2}-[\d]{1,2} [\d]{1,2}:[\d]{2}/)) {
        return moment(t).isAfter(); // In the future
      } else {
        return (t.match(/^[\d]+$/) || t.match(/^[\d]{1,2}:[\d]{2}$/)) !== null;
      }
    } else {
      return true;
    }
  }
});
