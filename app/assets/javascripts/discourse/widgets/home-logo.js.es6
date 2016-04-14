import DiscourseURL from 'discourse/lib/url';
import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import { iconNode } from 'discourse/helpers/fa-icon';

export default createWidget('home-logo', {
  tagName: 'div.title',

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
        return h('img#site-logo.logo-small', { attributes: { src: logoSmallUrl, width: 33, height: 33, alt: title } });
      } else {
        return iconNode('home');
      }
    } else if (showMobileLogo) {
      return h('img#site-logo.logo-big', { attributes: { src: mobileLogoUrl, alt: title } });
    } else if (logoUrl.length) {
      return h('img#site-logo.logo-big', { attributes: { src: logoUrl, alt: title } });
    } else {
      return h('h2#site-text-logo.text-logo', title);
    }
  },

  html() {
    return h('a', { attributes: { href: "/", 'data-auto-route': true } }, this.logo());
  },

  click(e) {
    // if they want to open in a new tab, let it so
    if (e.shiftKey || e.metaKey || e.ctrlKey || e.which === 2) { return true; }

    e.preventDefault();

    DiscourseURL.routeTo("/");
    return false;
  }
});
