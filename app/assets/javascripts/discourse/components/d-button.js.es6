import { iconHTML } from 'discourse/helpers/fa-icon';
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  tagName: 'button',
  classNameBindings: [':btn', 'noText'],
  attributeBindings: ['disabled', 'translatedTitle:title'],

  noText: Ember.computed.empty('translatedLabel'),

  @computed("title", "translatedLabel")
  translatedTitle(title, translatedLabel) {
    return title ? I18n.t(title) : translatedLabel;
  },

  @computed("label")
  translatedLabel(label) {
    if (label) return I18n.t(label);
  },

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
