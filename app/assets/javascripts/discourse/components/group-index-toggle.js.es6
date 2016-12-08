import { iconHTML } from 'discourse-common/helpers/fa-icon';
import { bufferedRender } from 'discourse-common/lib/buffered-render';

export default Ember.Component.extend(bufferedRender({
  tagName: 'th',
  classNames: ['sortable'],
  rerenderTriggers: ['order', 'asc'],

  buildBuffer(buffer) {
    buffer.push(I18n.t(this.get('i18nKey')));

    if (this.get('field') === this.get('order')) {
      buffer.push(iconHTML(this.get('asc') ? 'chevron-up' : 'chevron-down'));
    }
  },

  click() {
    if (this.get('order') === this.field) {
      this.set('asc', this.get('asc') ? null : true);
    } else {
      this.setProperties({ order: this.field, asc: null });
    }
  }
}));
