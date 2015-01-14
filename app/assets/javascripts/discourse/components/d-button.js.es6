import { iconHTML } from 'discourse/helpers/fa-icon';

export default Ember.Component.extend({
  tagName: 'button',
  classNameBindings: [':btn'],

  render: function(buffer) {
    var icon = this.get('icon');
    if (icon) {
      buffer.push(iconHTML(icon) + ' ');
    }
    buffer.push(I18n.t(this.get('label')));
  },

  click: function() {
    this.sendAction();
  }
});
