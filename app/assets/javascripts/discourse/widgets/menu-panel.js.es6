import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';

createWidget('menu-links', {
  html(attrs) {
    const links = [].concat(attrs.contents());
    const liOpts = { className: attrs.heading ? 'heading' : '' };

    const result = [];
    result.push(h('ul.menu-links.columned', links.map(l => h('li', liOpts, l))));

    result.push(h('div.clearfix'));
    if (!attrs.omitRule) {
      result.push(h('hr'));
    }
    return result;
  }
});

createWidget('menu-panel', {
  tagName: 'div.menu-panel',

  buildAttributes(attrs) {
    if (attrs.maxWidth) {
      return { 'data-max-width': attrs.maxWidth };
    }
  },

  html(attrs) {
    return h('div.panel-body', h('div.panel-body-contents.clearfix', attrs.contents()));
  }
});
