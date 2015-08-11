import StringBuffer from 'discourse/mixins/string-buffer';

export default Ember.View.extend(StringBuffer, {
  tagName: 'button',
  classNameBindings: [':btn', ':standard', 'dropDownToggle'],
  attributeBindings: ['title', 'data-toggle', 'data-share-url'],

  title: function() {
    return I18n.t(this.get('helpKey') || this.get('textKey'));
  }.property('helpKey', 'textKey'),

  text: function() {
    if (Ember.isEmpty(this.get('textKey'))) { return ""; }
    return I18n.t(this.get('textKey'));
  }.property('textKey'),

  renderString: function(buffer) {
    if (this.renderIcon) {
      this.renderIcon(buffer);
    }
    buffer.push(this.get('text'));
  }
});
