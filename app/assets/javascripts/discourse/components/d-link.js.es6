import computed from 'ember-addons/ember-computed-decorators';
import { iconHTML } from 'discourse/helpers/fa-icon';
import DiscourseURL from 'discourse/lib/url';

export default Ember.Component.extend({
  tagName: 'a',
  attributeBindings: ['translatedTitle:title', 'translatedTitle:aria-title', 'href'],

  @computed('path')
  href(path) {
    if (path) { return path; }

    const route = this.get('route');
    if (route) {
      const router = this.container.lookup('router:main');
      if (router && router.router) {
        return router.router.generate(route, this.get('model'));
      }
    }

    return '';
  },

  @computed("title", "label")
  translatedTitle(title, label) {
    const text = title || label;
    if (text) return I18n.t(text);
  },

  click() {
    const action = this.get('action');
    if (action) {
      this.sendAction('action');
      return false;
    }
    const href = this.get('href');
    if (href) {
      DiscourseURL.routeTo(href);
      return false;
    }
    return false;
  },

  render(buffer) {
    if (!!this.get('template')) {
      return this._super(buffer);
    }

    const icon = this.get('icon');
    if (icon) {
      buffer.push(iconHTML(icon));
    }

    const label = this.get('label');
    if (label) {
      if (icon) { buffer.push(" "); }

      buffer.push(I18n.t(label));
    }
  }

});
