const MAX_SHOWN = 5;

import StringBuffer from 'discourse/mixins/string-buffer';
import { iconHTML } from 'discourse/helpers/fa-icon';
import property from 'ember-addons/ember-computed-decorators';

const { get, isEmpty, Component } = Ember;

export default Component.extend(StringBuffer, {
  classNameBindings: [':gutter'],

  rerenderTriggers: ['expanded'],

  // Roll up links to avoid duplicates
  @property('links')
  collapsed(links) {
    const seen = {};
    const result = [];

    if (!isEmpty(links)) {
      links.forEach(function(l) {
        const title = get(l, 'title');
        if (!seen[title]) {
          result.pushObject(l);
          seen[title] = true;
        }
      });
    }
    return result;
  },

  renderString(buffer) {
    const links = this.get('collapsed');
    const collapsed = !this.get('expanded');

    if (!isEmpty(links)) {
      let toRender = links;
      if (collapsed) {
        toRender = toRender.slice(0, MAX_SHOWN);
      }

      buffer.push("<ul class='post-links'>");
      toRender.forEach(function(l) {
        const direction = get(l, 'reflection') ? 'inbound' : 'outbound',
            clicks = get(l, 'clicks');

        buffer.push(`<li><a href='${get(l, 'url')}' class='track-link ${direction}'>`);

        let title = get(l, 'title');
        if (!isEmpty(title)) {
          title = Handlebars.Utils.escapeExpression(title);
          buffer.push(Discourse.Emoji.unescape(title));
        }
        if (clicks) {
          buffer.push(`<span class='badge badge-notification clicks'>${clicks}</span>`);
        }
        buffer.push("</a></li>");
      });

      if (collapsed) {
        const remaining = links.length - MAX_SHOWN;
        if (remaining > 0) {
          buffer.push(`<li><a href class='toggle-more'>${I18n.t('post.more_links', {count: remaining})}</a></li>`);
        }
      }
      buffer.push('</ul>');
    }

    if (this.get('canReplyAsNewTopic')) {
      buffer.push(`<a href class='reply-new'>${iconHTML('plus')}${I18n.t('post.reply_as_new_topic')}</a>`);
    }
  },

  click(e) {
    const $target = $(e.target);
    if ($target.hasClass('toggle-more')) {
      this.toggleProperty('expanded');
      return false;
    } else if ($target.closest('.reply-new').length) {
      this.sendAction('newTopicAction', this.get('post'));
      return false;
    }
    return true;
  }
});
