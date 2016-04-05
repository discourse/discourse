import DiscourseURL from 'discourse/lib/url';
import { iconHTML } from 'discourse/helpers/fa-icon';
import { observes } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  widget: 'home-logo',
  showMobileLogo: null,
  linkUrl: null,
  classNames: ['title'],

  init() {
    this._super();
    this.showMobileLogo = this.site.mobileView && !Ember.isEmpty(this.siteSettings.mobile_logo_url);
    this.linkUrl = this.get('targetUrl') || '/';
  },

  @observes('minimized')
  _updateLogo() {
    // On mobile we don't minimize the logo
    if (!this.site.mobileView) {
      this.rerender();
    }
  },

  click(e) {
    // if they want to open in a new tab, let it so
    if (e.shiftKey || e.metaKey || e.ctrlKey || e.which === 2) { return true; }

    e.preventDefault();

    DiscourseURL.routeTo(this.linkUrl);
    return false;
  },

  render(buffer) {
    const { siteSettings } = this;
    const logoUrl = siteSettings.logo_url || '';
    const title = siteSettings.title;

    buffer.push(`<a href="${this.linkUrl}" data-auto-route="true">`);
    if (!this.site.mobileView && this.get('minimized')) {
      const logoSmallUrl = siteSettings.logo_small_url || '';
      if (logoSmallUrl.length) {
        buffer.push(`<img id='site-logo' class="logo-small" src="${logoSmallUrl}" width="33" height="33" alt="${title}">`);
      } else {
        buffer.push(iconHTML('home'));
      }
    } else if (this.showMobileLogo) {
      buffer.push(`<img id="site-logo" class="logo-big" src="${siteSettings.mobile_logo_url}" alt="${title}">`);
    } else if (logoUrl.length) {
      buffer.push(`<img id="site-logo" class="logo-big" src="${logoUrl}" alt="${title}">`);
    } else {
      buffer.push(`<h2 id="site-text-logo" class="text-logo">${title}</h2>`);
    }
    buffer.push('</a>');
  }

});
