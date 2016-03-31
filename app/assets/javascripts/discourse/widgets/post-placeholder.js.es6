import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';

export default createWidget('post-placeholder', {
  tagName: 'article.placeholder',

  html() {
    return h('div.row', [
             h('div.topic-avatar', h('div.placeholder-avatar')),
             h('div.topic-body', [
                h('div.placeholder-text'),
                h('div.placeholder-text'),
                h('div.placeholder-text')
               ])
           ]);
  }
});
