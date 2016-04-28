import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import { iconNode } from 'discourse/helpers/fa-icon';
import { wantsNewWindow } from 'discourse/lib/intercept-click';
import DiscourseURL from 'discourse/lib/url';

export default createWidget('home-logo', {
  tagName: 'div.title',

  settings: {
    href: '/'
  },

  logo() {
    const { siteSettings } = this;
    const mobileView = this.site.mobileView;

    const mobileLogoUrl = siteSettings.mobile_logo_url || "";
    const showMobileLogo = mobileView && (mobileLogoUrl.length > 0);

    const logoUrl = siteSettings.logo_url || '';
    const title = siteSettings.title;

    if (!mobileView && this.attrs.minimized) {
      const logoSmallUrl = siteSettings.logo_small_url || '';
      if (logoSmallUrl.length) {
        return h('img#site-logo.logo-small', { key: 'logo-small', attributes: { src: logoSmallUrl, width: 33, height: 33, alt: title } });
      } else {
        return iconNode('home');
      }
    } else if (showMobileLogo) {
      return h('img#site-logo.logo-big', { key: 'logo-mobile', attributes: { src: mobileLogoUrl, alt: title } });
    } else if (logoUrl.length) {
      return h('img#site-logo.logo-big', { key: 'logo-big', attributes: { src: logoUrl, alt: title } });
    } else {
      return h('h2#site-text-logo.text-logo', { key: 'logo-text' }, title);
    }
  },

  html() {
    return h('a', { attributes: { href: this.settings.href } }, this.logo());
  },

  click(e) {
    if (wantsNewWindow(e)) { return false; }
    e.preventDefault();
    DiscourseURL.routeTo(this.settings.href);
    return false;
  }

});
