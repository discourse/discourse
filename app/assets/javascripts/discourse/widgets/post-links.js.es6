import { iconNode } from 'discourse/helpers/fa-icon';
import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import RawHtml from 'discourse/widgets/raw-html';

export default createWidget('post-links', {
  tagName: 'div.post-links-container',
  buildKey: (attrs) => `post-links-${attrs.id}`,

  defaultState() {
    return { collapsed: true };
  },

  linkHtml(link) {
    const escapedTitle = Discourse.Emoji.unescape(Handlebars.Utils.escapeExpression(link.title));
    const linkBody = [new RawHtml({ html: `<span>${escapedTitle}</span>` })];
    if (link.clicks) {
      linkBody.push(h('span.badge.badge-notification.clicks', link.clicks.toString()));
    }

    return h('li',
      h('a.track-link', {
        className: link.reflection ? 'inbound' : 'outbound',
        attributes: { href: link.url }
      }, [iconNode(link.reflection ? 'arrow-left' : 'arrow-right'), linkBody])
    );
  },

  html(attrs, state) {
    const links = this.attrs.links || [];
    const dedupedLinks = _.uniq(links, true, l => l.title);
    const incomingLinks = dedupedLinks.filter(l => l.reflection);

    // if all links are outgoing, don't show any
    if (incomingLinks.length === 0) { return; }

    const result = [];

    // show all links
    if (dedupedLinks.length <= 5 || !state.collapsed) {
      _.each(dedupedLinks, l => result.push(this.linkHtml(l)));
    } else {
      // show up to 5 *incoming* links when collapsed
      const max = Math.min(5, incomingLinks.length);
      for (let i = 0; i < max; i++) {
        result.push(this.linkHtml(incomingLinks[i]));
      }
      // 'show more' link
      if (dedupedLinks.length > max) {
        result.push(h('li', this.attach('link', {
          labelCount: 'post_links.title',
          title: 'post_links.about',
          count: dedupedLinks.length - max,
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
