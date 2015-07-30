import { iconHTML } from 'discourse/helpers/fa-icon';

export default Ember.Component.extend({
  tagName: 'button',
  classNameBindings: [':btn', 'noText'],
  attributeBindings: ['disabled', 'translatedTitle:title'],

  noText: Ember.computed.empty('translatedLabel'),

  translatedTitle: function() {
    const title = this.get('title');
    return title ? I18n.t(title) : this.get('translatedLabel');
  }.property('title', 'translatedLabel'),

  translatedLabel: function() {
    const label = this.get('label');
    if (label) {
      return I18n.t(this.get('label'));
    }
  }.property('label'),

  render(buffer) {
    const label = this.get('translatedLabel'),
          icon = this.get('icon');

    if (label || icon) {
      if (icon) { buffer.push(iconHTML(icon) + ' '); }
      if (label) { buffer.push(label); }
    } else {
      // If no label or icon is present, yield
      return this._super(buffer);
    }
  },

  click() {
    this.sendAction("action", this.get("actionParam"));
    return false;
  }
});
