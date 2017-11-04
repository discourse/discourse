import RawHtml from 'discourse/widgets/raw-html';
import { createWidget } from 'discourse/widgets/widget';
import { emojiUnescape } from 'discourse/lib/text';
import { h } from 'virtual-dom';
import { iconNode } from 'discourse/helpers/fa-icon-node';

createWidget('user-menu-item', {
  tagName: 'li',

  html(attrs) {
    return [
      attrs.icon ? [ iconNode(attrs.icon), ' ' ] : '',
      h('a', { attributes: { href: attrs.href } }, new RawHtml({ html: '<span>' + emojiUnescape(attrs.title) + '</span>' }))
    ];
  }
});
