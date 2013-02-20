(function() {

  Discourse.InputTipView = Ember.View.extend(Discourse.Presence, {
    templateName: 'input_tip',
    classNameBindings: [':tip', 'good', 'bad'],
    good: (function() {
      return !this.get('validation.failed');
    }).property('validation'),
    bad: (function() {
      return this.get('validation.failed');
    }).property('validation'),
    triggerRender: (function() {
      return this.rerender();
    }).observes('validation'),
    render: function(buffer) {
      var icon, reason;
      if (reason = this.get('validation.reason')) {
        icon = this.get('good') ? 'icon-ok' : 'icon-remove';
        return buffer.push("<i class=\"icon " + icon + "\"></i> " + reason);
      }
    }
  });

}).call(this);
