import { default as computed } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  // subclasses need this
  layoutName: 'components/d-button',

  tagName: 'button',
  classNameBindings: [':btn', 'noText', 'btnType'],
  attributeBindings: ['disabled', 'translatedTitle:title', 'tabindex'],

  btnIcon: Ember.computed.notEmpty('icon'),

  @computed('icon', 'translatedLabel')
  btnType(icon, translatedLabel) {
    if (icon) {
      return translatedLabel ? "btn-icon-text" : "btn-icon";
    } else if (translatedLabel) {
      return "btn-text";
    }
  },

  noText: Ember.computed.empty('translatedLabel'),

  @computed("title")
  translatedTitle(title) {
    return title ? I18n.t(title) : this.get('translatedLabel');
  },

  @computed("label")
  translatedLabel(label) {
    if (label) return I18n.t(label);
  },

  click() {
    this.sendAction("action", this.get("actionParam"));
    return false;
  }
});
