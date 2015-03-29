import StringBuffer from 'discourse/mixins/string-buffer';

export default Discourse.View.extend(StringBuffer, {
  classNameBindings: [':tip', 'good', 'bad'],
  rerenderTriggers: ['validation'],

  bad: Em.computed.alias('validation.failed'),
  good: Em.computed.not('bad'),

  renderString: function(buffer) {
    var reason = this.get('validation.reason');
    if (reason) {
      var icon = this.get('good') ? 'fa-check' : 'fa-times';
      return buffer.push("<i class=\"fa " + icon + "\"></i> " + reason);
    }
  }
});
