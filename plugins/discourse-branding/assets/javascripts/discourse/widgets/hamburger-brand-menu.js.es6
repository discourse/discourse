import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';

export default createWidget('hamburger-brand-menu', {
  tagName: 'div.hamburger-panel',

  panelContents(generalLinks, iconLinks) {
    const results = [];

    results.push(this.attach('menu-links', { contents: () => generalLinks }));
    results.push(this.attach('nav-icons', { contents: () => iconLinks }));

    return results;
  },

  html(attrs) {
    return this.attach('menu-panel', { contents: () => this.panelContents(attrs.generalLinks, attrs.iconLinks) });
  },

  clickOutside() {
    this.sendWidgetAction('toggleHamburger');
 }
});
