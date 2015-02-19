import StringBuffer from 'discourse/mixins/string-buffer';

export default Ember.Component.extend(StringBuffer, {
  tagName: 'h2',
  rerenderTriggers: ['period.title'],

  renderString: function(buffer) {
    buffer.push("<i class='fa fa-calendar-o'></i> " + this.get('period.title'));
  }
});
