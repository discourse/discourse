import { iconNode } from 'discourse/helpers/fa-icon';
import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import RawHtml from 'discourse/widgets/raw-html';
import { emojiUnescape } from 'discourse/lib/text';

export default createWidget('post-links', {
  tagName: 'div.post-links-container',
  buildKey: (attrs) => `post-links-${attrs.id}`,

  defaultState() {
    return { collapsed: true };
  },

  linkHtml(link) {
    const escapedTitle = emojiUnescape(Handlebars.Utils.escapeExpression(link.title));
    const linkBody = [new RawHtml({ html: `<span>${escapedTitle}</span>` })];
    if (link.clicks) {
      linkBody.push(h('span.badge.badge-notification.clicks', link.clicks.toString()));
    }

    return h('li',
      h('a.track-link', {
        className: 'inbound',
        attributes: { href: link.url }
      }, [iconNode('link'), linkBody])
    );
  },

  html(attrs, state) {
    if (!this.attrs.links || this.attrs.links.length === 0) {
      // shortcut all work
      return;
    }

    // only show incoming
    const links = _(this.attrs.links)
                      .filter(l => l.reflection)
                      .uniq(true, l => l.title)
                      .value();

    if (links.length === 0) { return; }

    const result = [];

    // show all links
    if (links.length <= 5 || !state.collapsed) {
      _.each(links, l => result.push(this.linkHtml(l)));
    } else {
      const max = Math.min(5, links.length);
      for (let i = 0; i < max; i++) {
        result.push(this.linkHtml(links[i]));
      }
      // 'show more' link
      if (links.length > max) {
        result.push(h('li', this.attach('link', {
          labelCount: 'post_links.title',
          title: 'post_links.about',
          count: links.length - max,
          action: 'expandLinks',
          className: 'expand-links'
        })));
      }
    }

    if (result.length) {
      return h('ul.post-links', result);
    }
  },

  expandLinks() {
    this.state.collapsed = false;
  }
});
