import computed from 'ember-addons/ember-computed-decorators';
import { iconHTML } from 'discourse/helpers/fa-icon';
import interceptClick from 'discourse/lib/intercept-click';

export default Ember.Component.extend({
  tagName: 'a',
  classNames: ['d-link'],
  attributeBindings: ['translatedTitle:title', 'translatedTitle:aria-title', 'href'],

  @computed('path')
  href(path) {
    if (path) { return path; }

    const route = this.get('route');
    if (route) {
      const router = this.container.lookup('router:main');
      if (router && router.router) {
        const params = [route];
        const model = this.get('model');
        if (model) {
          params.push(model);
        }

        return router.router.generate.apply(router.router, params);
      }
    }

    return '';
  },

  @computed("title", "label")
  translatedTitle(title, label) {
    const text = title || label;
    if (text) return I18n.t(text);
  },

  click(e) {
    const action = this.get('action');
    if (action) {
      this.sendAction('action');
      return false;
    }

    return interceptClick(e);
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

      const count = this.get('count');
      buffer.push(I18n.t(label, { count }));
    }
  }

});
