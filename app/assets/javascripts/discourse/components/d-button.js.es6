import { iconHTML } from 'discourse/helpers/fa-icon';

export default Ember.Component.extend({
  tagName: 'button',
  classNameBindings: [':btn'],
  attributeBindings: ['disabled', 'translatedTitle:title'],

  translatedTitle: function() {
    var title = this.get('title');
    if (title) {
      return I18n.t(this.get('title'));
    } else {
      return this.get('translatedLabel');
    }
  }.property('title'),

  translatedLabel: function() {
    var label = this.get('label');
    if (label) {
      return I18n.t(this.get('label'));
    }
  }.property('label'),

  render: function(buffer) {
    var label = this.get('translatedLabel'),
        icon = this.get('icon');

    if (label || icon) {
      if (icon) { buffer.push(iconHTML(icon) + ' '); }
      if (label) { buffer.push(label); }
    } else {
      // If no label or icon is present, yield
      return this._super();
    }
  },

  click: function() {
    this.sendAction('action', this.get('actionParam'));
  }
});
