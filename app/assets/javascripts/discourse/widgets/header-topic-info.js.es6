import { applyDecorators, createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import { iconNode } from 'discourse/helpers/fa-icon-node';
import DiscourseURL from 'discourse/lib/url';
import RawHtml from 'discourse/widgets/raw-html';
import renderTags from 'discourse/lib/render-tags';
import { topicFeaturedLinkNode } from 'discourse/lib/render-topic-featured-link';

export default createWidget('header-topic-info', {
  tagName: 'div.extra-info-wrapper',

  html(attrs, state) {
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

      let extra = [];
      const tags = renderTags(topic);
      if (tags && tags.length > 0) {
        extra.push(new RawHtml({html: tags}));
      }

      extra = extra.concat(applyDecorators(this, 'after-tags', attrs, state));

      if (this.siteSettings.topic_featured_link_enabled) {
        const featured = topicFeaturedLinkNode(attrs.topic);
        if (featured) {
          extra.push(featured);
        }
      }
      if (extra.length) {
        title.push(h('div.topic-header-extra', extra));
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
