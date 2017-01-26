import { getCustomHTML } from 'discourse/helpers/custom-html';
import { getOwner } from 'discourse-common/lib/get-owner';

export default Ember.Component.extend({
  init() {
    this._super();
    const name = this.get('name');
    const html = getCustomHTML(name);

    if (html) {
      this.set('html', html);
      this.set('layoutName', 'components/custom-html-container');
    } else {
      const template = getOwner(this).lookup(`template:${name}`);
      if (template) {
        this.set('layoutName', name);
      }
    }
  }
});
