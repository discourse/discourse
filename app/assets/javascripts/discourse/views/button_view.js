(function() {

  Discourse.ButtonView = Ember.View.extend(Discourse.Presence, {
    tagName: 'button',
    classNameBindings: [':btn', ':standard', 'dropDownToggle'],
    attributeBindings: ['data-not-implemented', 'title', 'data-toggle', 'data-share-url'],
    title: (function() {
      return Em.String.i18n(this.get('helpKey') || this.get('textKey'));
    }).property('helpKey'),
    text: (function() {
      return Em.String.i18n(this.get('textKey'));
    }).property('textKey'),
    render: function(buffer) {
      if (this.renderIcon) {
        this.renderIcon(buffer);
      }
      return buffer.push(this.get('text'));
    }
  });

}).call(this);
