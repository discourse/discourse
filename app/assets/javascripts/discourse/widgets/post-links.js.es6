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

  html(attrs, state) {
    const links = this.attrs.links || [];

    const result = [];
    if (links.length) {

      const seenTitles = {};

      let titleCount = 0;

      let hasMore = links.any((l) => {
        if (this.state.collapsed && titleCount === 5) { return true; }

        let title = l.title;
        if (title && !seenTitles[title]) {
          seenTitles[title] = true;
          titleCount++;
          const linkBody = [new RawHtml({html: `<span>${Discourse.Emoji.unescape(Handlebars.Utils.escapeExpression(title))}</span>`})];
          if (l.clicks) {
            linkBody.push(h('span.badge.badge-notification.clicks', l.clicks.toString()));
          }

          result.push(h('li',
            h('a.track-link', {
              className: l.reflection ? 'inbound' : 'outbound',
              attributes: {href: l.url}
            }, [linkBody, iconNode(l.reflection ? 'arrow-left' : 'arrow-right')])
          ));
        }
      });

      if (hasMore) {
        result.push(h('li', this.attach('link', {
          labelCount: `post_links.title`,
          title: "post_links.about",
          count: links.length,
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
