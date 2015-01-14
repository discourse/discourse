import { iconHTML } from 'discourse/helpers/fa-icon';

export default Ember.Component.extend({
  tagName: 'button',
  classNameBindings: [':btn'],
  attributeBindings: ['disabled', 'translatedTitle:title'],

  translatedTitle: function() {
    var label = this.get('label');
    if (label) {
      return I18n.t(this.get('label'));
    }
  }.property('label'),

  render: function(buffer) {
    var title = this.get('translatedTitle'),
        icon = this.get('icon');

    if (title || icon) {
      if (icon) { buffer.push(iconHTML(icon) + ' '); }
      if (title) { buffer.push(title); }
    } else {
      // If no label or icon is present, yield
      return this._super();
    }
  },

  click: function() {
    this.sendAction();
  }
});
