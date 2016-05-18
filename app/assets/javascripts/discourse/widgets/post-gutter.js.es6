import { iconNode } from 'discourse/helpers/fa-icon';
import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import RawHtml from 'discourse/widgets/raw-html';

const MAX_GUTTER_LINKS = 5;

export default createWidget('post-gutter', {
  tagName: 'div.gutter',
  buildKey: (attrs) => `post-gutter-${attrs.id}`,

  defaultState() {
    return { collapsed: true };
  },

  html(attrs, state) {
    const links = this.attrs.links || [];

    const result = [];
    let toShow = links.length;
    if (state.collapsed && toShow > MAX_GUTTER_LINKS) { toShow = MAX_GUTTER_LINKS; }

    const seenTitles = {};

    let titleCount = 0;
    links.forEach(function(l) {
      let title = l.title;
      if (title && !seenTitles[title]) {
        seenTitles[title] = true;
        titleCount++;
        if (result.length < toShow) {
          const linkBody = [new RawHtml({html: `<span>${Discourse.Emoji.unescape(Handlebars.Utils.escapeExpression(title))}</span>`})];
          if (l.clicks) {
            linkBody.push(h('span.badge.badge-notification.clicks', l.clicks.toString()));
          }

          const className = l.reflection ? 'inbound' : 'outbound';
          const link = h('a.track-link', {className, attributes: {href: l.url}}, linkBody);
          result.push(h('li', link));
        }
      }
    });

    if (state.collapsed) {
      const remaining = titleCount - MAX_GUTTER_LINKS;

      if (remaining > 0) {
        result.push(h('li', h('a.toggle-more', I18n.t('post.more_links', {count: remaining}))));
      }
    }

    if (attrs.canReplyAsNewTopic) {
      result.push(h('a.reply-new', [iconNode('plus'), I18n.t('post.reply_as_new_topic')]));
    }

    return h('ul.post-links', result);
  },

  click(e) {
    const $target = $(e.target);
    if ($target.hasClass('toggle-more')) {
      this.sendWidgetAction('showAll');
    } else if ($target.closest('.reply-new').length) {
      this.sendWidgetAction('newTopicAction');
    }
    return true;
  },

  showAll() {
    this.state.collapsed = false;
  }
});
