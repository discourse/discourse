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
      if (state.collapsed) {
        return this.attach('link', {
          labelCount: `post_links.title`,
          count: links.length,
          action: 'expandLinks',
          className: 'expand-links'
        });
      }

      const seenTitles = {};

      let titleCount = 0;
      links.forEach(function(l) {
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
    }

    // if (attrs.canReplyAsNewTopic) {
    //   result.push(h('li', this.attach('link', {
    //                 className: 'reply-new',
    //                 contents: () => [I18n.t('post.reply_as_new_topic'), iconNode('plus')],
    //                 action: 'newTopicAction'
    //               })));
    // }

    return h('ul.post-links', result);
  },

  expandLinks() {
    this.state.collapsed = false;
  }
});
