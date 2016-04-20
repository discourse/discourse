import PostCooked from 'discourse/widgets/post-cooked';
import DecoratorHelper from 'discourse/widgets/decorator-helper';
import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import { iconNode } from 'discourse/helpers/fa-icon';
import DiscourseURL from 'discourse/lib/url';

createWidget('post-link-arrow', {
  html(attrs) {
   if (attrs.above) {
     return h('a.post-info.arrow', {
       attributes: { title: I18n.t('topic.jump_reply_up') }
     }, iconNode('arrow-up'));
   } else {
     return h('a.post-info.arrow', {
       attributes: { title: I18n.t('topic.jump_reply_down') }
     }, iconNode('arrow-down'));
   }
  },

  click() {
    DiscourseURL.routeTo(this.attrs.shareUrl);
  }
});

export default createWidget('embedded-post', {
  buildKey: attrs => `embedded-post-${attrs.id}`,

  html(attrs, state) {
    return [
      h('div.reply', {attributes: {'data-post-id': attrs.id}}, [
        h('div.row', [
          this.attach('post-avatar', attrs),
          h('div.topic-body', [
            h('div.topic-meta-data', [
              this.attach('poster-name', attrs),
              this.attach('post-link-arrow', { above: state.above, shareUrl: attrs.shareUrl })
            ]),
            new PostCooked(attrs, new DecoratorHelper(this))
          ])
        ])
      ])
    ];
  }
});
