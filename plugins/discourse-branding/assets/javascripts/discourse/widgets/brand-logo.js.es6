import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import { wantsNewWindow } from 'discourse/lib/intercept-click';
import DiscourseURL from 'discourse/lib/url';

export default createWidget('brand-logo', {
  tagName: 'div.title',

  logo() {
    const { siteSettings } = this;
    const mobileView = this.site.mobileView;

    const mobileLogoUrl = siteSettings.mobile_brand_logo_url || "";
    const showMobileLogo = mobileView && (mobileLogoUrl.length > 0);

    const logoUrl = siteSettings.brand_logo_url || '';
    const title = siteSettings.brand_name;

    if (showMobileLogo) {
      return h('img#brand-logo.logo-big', { key: 'logo-mobile', attributes: { src: mobileLogoUrl, alt: title } });
    } else if (logoUrl.length) {
      return h('img#brand-logo.logo-big', { key: 'logo-big', attributes: { src: logoUrl, alt: title } });
    } else {
      return h('h2#brand-text-logo.text-logo', { key: 'logo-text' }, title);
    }
  },

  html() {
    const { siteSettings } = this;
    return h('a', { attributes: { href: siteSettings.brand_url } }, this.logo());
  },

  click(e) {
    if (wantsNewWindow(e)) { return false; }
    e.preventDefault();

    DiscourseURL.routeToTag($(e.target).closest('a')[0]);
    return false;
  }
});
