import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import { iconNode } from 'discourse/helpers/fa-icon';
import DiscourseURL from 'discourse/lib/url';
import RawHtml from 'discourse/widgets/raw-html';
import { tagNode } from 'discourse/lib/render-tag';

export default createWidget('header-topic-info', {
  tagName: 'div.extra-info-wrapper',

  html(attrs) {
    const topic = attrs.topic;

    const heading = [];

    const showPM = !topic.get('is_warning') && topic.get('isPrivateMessage');
    if (showPM) {
      const href = this.currentUser && this.currentUser.pmPath(topic);
      if (href) {
        heading.push(h('a', { attributes: { href } },
                      h('span.private-message-glyph', iconNode('envelope'))));
      }
    }
    const loaded = topic.get('details.loaded');

    if (loaded) {
      heading.push(this.attach('topic-status', attrs));

      const titleHTML = new RawHtml({ html: `<span>${topic.get('fancyTitle')}</span>` });
      heading.push(this.attach('link', { className: 'topic-link',
                                         action: 'jumpToTopPost',
                                         href: topic.get('url'),
                                         contents: () => titleHTML }));
    }

    const title = [h('h1', heading)];
    if (loaded) {
      const category = topic.get('category');
      if (category && (!category.get('isUncategorizedCategory') || !this.siteSettings.suppress_uncategorized_badge)) {
        const parentCategory = category.get('parentCategory');
        if (parentCategory) {
          title.push(this.attach('category-link', { category: parentCategory }));
        }
        title.push(this.attach('category-link', { category }));
      }

      if (this.siteSettings.tagging_enabled) {
        const tags = topic.get('tags') || [];
        if (tags.length) {
          title.push(h('div.list-tags', tags.map(tagNode)));
        }
      }
    }

    const contents = h('div.title-wrapper', title);
    return h('div.extra-info', { className: title.length > 1 ? 'two-rows' : '' }, contents);
  },

  jumpToTopPost() {
    const topic = this.attrs.topic;
    if (topic) {
      DiscourseURL.routeTo(topic.get('firstPostUrl'));
    }
  }
});
